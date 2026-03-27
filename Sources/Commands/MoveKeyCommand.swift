import ArgumentParser
import Foundation

struct MoveKeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move-key",
        abstract: "Move a Keychain item from one Keychain to another."
    )

    @Option(name: .short, parsing: .upToNextOption, help: "Keychain service name(s).")
    var service: [String]

    @Option(name: .short, help: "Keychain account name (optional, applies to all services).")
    var account: String?

    @Option(name: .customLong("from"), help: "Source Keychain path (default: login keychain).")
    var from: String?

    @Option(name: .customLong("to"), help: "Destination Keychain path.")
    var to: String

    mutating func run() throws {
        let resolvedFrom = from ?? ProcessInfo.processInfo.environment["DOTENV_CRYPT_KEYCHAIN"]
        try Auth.requireTouchID(reason: "Move \(service.count) item(s) between keychains")
        for svc in service {
            let label = account.map { "'\($0)' in '\(svc)'" } ?? "'\(svc)'"
            try Keychain.moveItem(service: svc, account: account, from: resolvedFrom, to: to)
            print("Moved \(label) to \(to).")
        }
    }
}
