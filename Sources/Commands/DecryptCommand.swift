import ArgumentParser
import Foundation

struct DecryptCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "decrypt",
        abstract: "Decrypt one or more values in a .env file in-place."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    @OptionGroup var keychain: KeychainOptions

    @Argument(help: "Keys whose values should be decrypted.")
    var keys: [String]

    mutating func run() throws {
        let url = URL(fileURLWithPath: file)
        var envFile = try EnvFile(contentsOf: url)

        for key in keys {
            guard let value = envFile.value(for: key) else {
                throw EnvFileError.keyNotFound(key)
            }
            if !Crypto.isEncrypted(value) {
                print("'\(key)' is not encrypted, skipping.")
            }
        }

        let keyList = keys.joined(separator: ", ")
        try Auth.requireTouchID(reason: "dotenv-crypt wants to decrypt: \(keyList)")
        let encKey = try Keychain.loadKey(keychainPath: keychain.resolved)

        for key in keys {
            guard let value = envFile.value(for: key), Crypto.isEncrypted(value) else { continue }
            let decrypted = try Crypto.decrypt(value, using: encKey)
            try envFile.setValue(decrypted, for: key)
            print("Decrypted '\(key)'.")
        }

        try envFile.write(to: url)
    }
}
