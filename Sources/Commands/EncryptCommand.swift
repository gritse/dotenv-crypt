import ArgumentParser
import Foundation

struct EncryptCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "encrypt",
        abstract: "Encrypt one or more values in a .env file in-place."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    @OptionGroup var keychain: KeychainOptions

    @Argument(help: "Keys whose values should be encrypted.")
    var keys: [String]

    mutating func run() throws {
        let url = URL(fileURLWithPath: file)
        var envFile = try EnvFile(contentsOf: url)

        // Validate all keys before touching auth or the file
        for key in keys {
            guard let value = envFile.value(for: key) else {
                throw EnvFileError.keyNotFound(key)
            }
            if Crypto.isEncrypted(value) {
                print("'\(key)' is already encrypted, skipping.")
            }
        }

        try Auth.requireTouchID(reason: "dotenv-crypt wants to encrypt secrets")
        let encKey = try Keychain.loadKey(keychainPath: keychain.resolved)

        for key in keys {
            guard let value = envFile.value(for: key), !Crypto.isEncrypted(value) else { continue }
            let encrypted = try Crypto.encrypt(value, using: encKey)
            try envFile.setValue(encrypted, for: key)
            print("Encrypted '\(key)'.")
        }

        try envFile.write(to: url)
    }
}
