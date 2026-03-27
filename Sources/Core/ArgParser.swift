/// A minimal, schema-light CLI argument parser.
/// Caller declares which flags consume a value; everything else is parsed as a boolean flag.
struct ArgParser {
    let valueFlags: Set<String>

    enum Token: Equatable {
        case option(name: String, value: String) // --foo bar  or  --foo=bar
        case flag(String)                         // --verbose  or  -v
        case positional(String)                   // bare word
    }

    func parse(_ args: [String]) -> [Token] {
        var tokens: [Token] = []
        var i = args.startIndex

        while i < args.endIndex {
            let arg = args[i]

            if arg == "--" {
                args[args.index(after: i)...].forEach { tokens.append(.positional($0)) }
                break
            }

            let isLongFlag  = arg.hasPrefix("--") && arg.count > 2
            let isShortFlag = !arg.hasPrefix("--") && arg.hasPrefix("-") && arg.count >= 2

            if isLongFlag || isShortFlag {
                if let eq = arg.firstIndex(of: "=") {
                    // --foo=bar  or  -f=bar
                    let name  = String(arg[..<eq])
                    let value = String(arg[arg.index(after: eq)...])
                    tokens.append(.option(name: name, value: value))
                } else if valueFlags.contains(arg) {
                    let next = args.index(after: i)
                    if next < args.endIndex && !args[next].hasPrefix("-") {
                        tokens.append(.option(name: arg, value: args[next]))
                        i = next
                    } else {
                        tokens.append(.flag(arg)) // missing value, treat as boolean
                    }
                } else {
                    tokens.append(.flag(arg))
                }
            } else {
                tokens.append(.positional(arg))
            }

            i = args.index(after: i)
        }

        return tokens
    }
}

extension Array where Element == ArgParser.Token {
    /// Returns the value of the first matching option flag, or nil.
    func firstOption(named names: String...) -> String? {
        for token in self {
            if case .option(let name, let value) = token, names.contains(name) {
                return value
            }
        }
        return nil
    }

    /// Returns the index of the first positional argument matching the given value.
    func firstPositionalIndex(of value: String) -> Int? {
        for (i, token) in enumerated() {
            if case .positional(let v) = token, v == value { return i }
        }
        return nil
    }
}
