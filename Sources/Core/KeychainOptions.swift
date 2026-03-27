import ArgumentParser
import Foundation

struct KeychainOptions: ParsableArguments {
    @Option(name: .customLong("keychain"), help: "Path to a specific macOS Keychain file. Falls back to DOTENV_CRYPT_KEYCHAIN env var.")
    var keychain: String?

    /// Resolved keychain path: CLI flag → DOTENV_CRYPT_KEYCHAIN env var → nil (default keychain).
    var resolved: String? {
        keychain ?? ProcessInfo.processInfo.environment["DOTENV_CRYPT_KEYCHAIN"]
    }
}
