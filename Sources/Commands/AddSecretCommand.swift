import ArgumentParser
import Foundation

struct AddSecretCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-secret",
        abstract: "Read a secret from stdin and store it in Keychain."
    )

    @Option(name: .short, help: "Keychain service name.")
    var service: String

    @Option(name: .short, help: "Keychain account name.")
    var account: String

    @Flag(name: .long, help: "Keep trailing newline(s) from stdin.")
    var keepNewline: Bool = false

    @OptionGroup var keychain: KeychainOptions

    mutating func run() throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty else {
            throw AddSecretError.emptyInput
        }

        var secret = data
        if !keepNewline {
            while let last = secret.last, last == 0x0A || last == 0x0D {
                secret.removeLast()
            }
            if secret.isEmpty {
                throw AddSecretError.emptyInput
            }
        }

        try Keychain.saveItem(secret, service: service, account: account, keychainPath: keychain.resolved)
        print("Saved '\(account)' in '\(service)'.")
    }
}

enum AddSecretError: Error, CustomStringConvertible {
    case emptyInput

    var description: String {
        switch self {
        case .emptyInput:
            "No secret provided on stdin"
        }
    }
}
