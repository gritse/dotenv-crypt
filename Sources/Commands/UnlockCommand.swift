import ArgumentParser
import Foundation

struct UnlockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unlock",
        abstract: "Suppress the Touch ID prompt for a specific .env file for N minutes."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    @Option(name: [.short, .long], help: "Minutes to keep the file unlocked.")
    var minutes: Int

    @OptionGroup var keychain: KeychainOptions

    mutating func run() throws {
        guard minutes > 0 else {
            throw ValidationError("--minutes must be greater than 0.")
        }
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(file)")
        }

        try Auth.requireTouchID(reason: "Unlock \(url.lastPathComponent) for \(minutes) min")

        let key = try Keychain.loadKey(keychainPath: keychain.resolved)
        let content = try Data(contentsOf: url)
        try UnlockStore.write(envURL: url, content: content, minutes: minutes, key: key)

        let expiry = Date().addingTimeInterval(Double(minutes) * 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("Unlocked \(UnlockStore.absolutePath(for: file)) until ~\(formatter.string(from: expiry)) (\(minutes) min).")
    }
}
