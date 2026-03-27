import ArgumentParser
import CryptoKit

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Generate an encryption key and store it in Keychain."
    )

    @OptionGroup var keychain: KeychainOptions

    mutating func run() throws {
        guard !Keychain.keyExists(keychainPath: keychain.resolved) else {
            throw KeychainError.alreadyExists
        }

        let key = SymmetricKey(size: .bits256)
        try Keychain.saveKey(key, keychainPath: keychain.resolved)
        print("Encryption key stored in Keychain.")
    }
}
