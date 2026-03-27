import ArgumentParser
import Foundation

struct TagCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tag",
        abstract: "Set the Kind (description) on Keychain items."
    )

    @Option(name: .short, parsing: .upToNextOption, help: "Keychain service name(s).")
    var service: [String]

    @Option(name: .short, help: "Keychain account name (optional, applies to all services).")
    var account: String?

    @Option(name: .shortAndLong, help: "Kind string to set (default: \"dotenv-crypt key\").")
    var kind: String = "dotenv-crypt key"

    @OptionGroup var keychainOptions: KeychainOptions

    mutating func run() throws {
        try Auth.requireTouchID(reason: "Update Kind on \(service.count) item(s)")
        for svc in service {
            let label = account.map { "'\($0)' in '\(svc)'" } ?? "'\(svc)'"
            try Keychain.updateDescription(kind, service: svc, account: account, keychainPath: keychainOptions.resolved)
            print("Tagged \(label) as \"\(kind)\".")
        }
    }
}
