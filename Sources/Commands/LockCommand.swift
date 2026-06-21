import ArgumentParser
import Foundation

struct LockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lock",
        abstract: "Revoke an unlock early, re-enabling the Touch ID prompt for a .env file."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    @Flag(name: .long, help: "Clear all unlock records, not just this file.")
    var all = false

    mutating func run() throws {
        if all {
            let count = UnlockStore.clearAll()
            print("Cleared \(count) unlock record(s).")
            return
        }

        let url = URL(fileURLWithPath: file)
        if UnlockStore.clear(envURL: url) {
            print("Locked \(UnlockStore.absolutePath(for: file)).")
        } else {
            print("No active unlock for \(UnlockStore.absolutePath(for: file)).")
        }
    }
}
