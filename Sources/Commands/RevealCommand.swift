import ArgumentParser
import Foundation

struct RevealCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reveal",
        abstract: "Decrypt and print a single secret value to stdout."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    @OptionGroup var keychain: KeychainOptions

    @Argument(help: "Key to reveal.")
    var key: String

    mutating func run() throws {
        let url = URL(fileURLWithPath: file)
        let file = try EnvFile(contentsOf: url)

        guard let value = file.value(for: key) else {
            throw EnvFileError.keyNotFound(key)
        }
        try Auth.requireTouchID(reason: "Reveal '\(key)'")

        if Crypto.isEncrypted(value) {
            let encKey = try Keychain.loadKey(keychainPath: keychain.resolved)
            print(try Crypto.decrypt(value, using: encKey))
        } else {
            print(value)
        }
    }
}
