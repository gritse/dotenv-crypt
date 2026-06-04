import ArgumentParser
import Foundation
import Security

struct GenerateEnvSecretCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-env-secret",
        abstract: "Generate random secrets, append them to a .env file, and encrypt in-place."
    )

    @Option(name: [.short, .long], help: "Path to the .env file (created if missing).")
    var file: String = ".env"

    @Option(name: [.short, .long], help: "Number of random bytes per secret (before base64 encoding).")
    var size: Int

    @OptionGroup var keychain: KeychainOptions

    @Argument(help: "Keys to generate and encrypt.")
    var keys: [String]

    mutating func run() throws {
        guard size > 0 else {
            throw GenerateEnvSecretError.invalidSize(size)
        }
        guard !keys.isEmpty else {
            throw GenerateEnvSecretError.noKeys
        }

        let url = URL(fileURLWithPath: file)
        var envFile = try EnvFile.loadOrCreate(at: url)

        for key in keys {
            if envFile.value(for: key) != nil {
                throw EnvFileError.keyAlreadyExists(key)
            }
        }

        try Auth.requireTouchID(reason: "dotenv-crypt wants to generate and encrypt secrets")
        let encKey = try Keychain.loadKey(keychainPath: keychain.resolved)

        for key in keys {
            let plaintext = try generateUrlSafeBase64(byteCount: size)
            let encrypted = try Crypto.encrypt(plaintext, using: encKey)
            try envFile.append(key: key, value: encrypted)
            print("Generated and encrypted '\(key)'.")
        }

        try envFile.write(to: url)
    }

    private func generateUrlSafeBase64(byteCount: Int) throws -> String {
        var bytes = Data(count: byteCount)
        let status = bytes.withUnsafeMutableBytes { buf -> OSStatus in
            guard let base = buf.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, byteCount, base)
        }
        guard status == errSecSuccess else {
            throw GenerateEnvSecretError.randomFailed(status)
        }
        return bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

enum GenerateEnvSecretError: Error, CustomStringConvertible {
    case invalidSize(Int)
    case noKeys
    case randomFailed(OSStatus)

    var description: String {
        switch self {
        case .invalidSize(let n): "Invalid --size \(n): must be > 0"
        case .noKeys: "No keys provided"
        case .randomFailed(let s): "Failed to generate random bytes (status \(s))"
        }
    }
}
