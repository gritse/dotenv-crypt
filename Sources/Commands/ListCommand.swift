import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all keys in a .env file."
    )

    @Option(name: [.short, .long], help: "Path to the .env file.")
    var file: String = ".env"

    mutating func run() throws {
        let url = URL(fileURLWithPath: file)
        let file = try EnvFile(contentsOf: url)

        for (key, value) in file.allEntries() {
            let tag = Crypto.isEncrypted(value) ? "[encrypted]" : "[plaintext]"
            print("\(tag) \(key)")
        }
    }
}
