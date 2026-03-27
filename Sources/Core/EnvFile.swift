import Foundation

struct EnvFile {
    private var rawLines: [String]

    init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        rawLines = text.components(separatedBy: "\n")
    }

    // Returns (key, value) for a key=value line, nil for comments/blanks/etc.
    private static func parseEntry(_ line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        guard let eqIdx = trimmed.firstIndex(of: "=") else { return nil }
        let key = String(trimmed[trimmed.startIndex..<eqIdx])
        let value = String(trimmed[trimmed.index(after: eqIdx)...])
        return (key, value)
    }

    func value(for key: String) -> String? {
        rawLines
            .compactMap { Self.parseEntry($0) }
            .first { $0.key == key }?
            .value
    }

    mutating func setValue(_ value: String, for key: String) throws {
        guard let idx = rawLines.firstIndex(where: { Self.parseEntry($0)?.key == key }) else {
            throw EnvFileError.keyNotFound(key)
        }
        rawLines[idx] = "\(key)=\(value)"
    }

    func allEntries() -> [(key: String, value: String)] {
        rawLines.compactMap { Self.parseEntry($0) }
    }

    func serialized() -> String {
        rawLines.joined(separator: "\n")
    }

    func write(to url: URL) throws {
        try serialized().write(to: url, atomically: true, encoding: .utf8)
    }
}

enum EnvFileError: Error, CustomStringConvertible {
    case keyNotFound(String)

    var description: String {
        switch self {
        case .keyNotFound(let k): "Key '\(k)' not found in .env file"
        }
    }
}
