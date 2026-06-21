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
        let content = try Data(contentsOf: url)
        let envFile = EnvFile(contents: String(decoding: content, as: UTF8.self))

        guard let value = envFile.value(for: key) else {
            throw EnvFileError.keyNotFound(key)
        }

        let encKey = try Keychain.loadKey(keychainPath: keychain.resolved)
        try UnlockStore.requireTouchIDUnlessUnlocked(envURL: url, content: content, key: encKey, reason: "Reveal '\(key)'")
        print(Crypto.isEncrypted(value) ? try Crypto.decrypt(value, using: encKey) : value)
    }
}
