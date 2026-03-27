import ArgumentParser
import Foundation
import Security

struct SecretCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "secret",
        abstract: "Read a Keychain item with Touch ID and print its value to stdout."
    )

    @Option(name: .short, help: "Keychain service name.")
    var service: String

    @Option(name: .short, help: "Keychain account name (optional).")
    var account: String?

    mutating func run() throws {
        let label = account.map { "'\($0)' in '\(service)'" } ?? "'\(service)'"
        try Auth.requireTouchID(reason: "dotenv-crypt wants to access \(label)")

        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw SecretError.notFound(label: label, status: status)
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw SecretError.notUTF8
        }

        print(value)
    }
}

enum SecretError: Error, CustomStringConvertible {
    case notFound(label: String, status: OSStatus)
    case notUTF8

    var description: String {
        switch self {
        case .notFound(let label, let status):
            "No keychain item found for \(label) (status \(status))"
        case .notUTF8:
            "Keychain item data is not valid UTF-8"
        }
    }
}
