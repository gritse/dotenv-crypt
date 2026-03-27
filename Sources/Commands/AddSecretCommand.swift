import ArgumentParser
import CryptoKit
import Foundation
import Security

struct AddSecretCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-secret",
        abstract: "Generate a random secret and store it in Keychain."
    )

    @Option(name: .short, help: "Keychain service name.")
    var service: String

    @Option(name: .short, help: "Keychain account name.")
    var account: String

    @OptionGroup var keychain: KeychainOptions

    mutating func run() throws {
        let secret = SymmetricKey(size: .bits256)
            .withUnsafeBytes { Data($0) }
            .base64EncodedString()
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))

        try Keychain.saveItem(Data(secret.utf8), service: service, account: account, keychainPath: keychain.resolved)
        print("Saved '\(account)' in '\(service)'.")
    }
}

enum AddSecretError: Error, CustomStringConvertible {
    case alreadyExists(service: String, account: String)
    case saveFailed(OSStatus)

    var description: String {
        switch self {
        case .alreadyExists(let s, let a):
            "Item already exists for service '\(s)', account '\(a)'"
        case .saveFailed(let status):
            "Failed to save keychain item (status \(status))"
        }
    }
}
