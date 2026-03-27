import CryptoKit
import Foundation

enum Crypto {
    static let encryptedPrefix = "enc:v1:"

    static func isEncrypted(_ value: String) -> Bool {
        value.hasPrefix(encryptedPrefix)
    }

    static func encrypt(_ plaintext: String, using key: SymmetricKey) throws -> String {
        let data = Data(plaintext.utf8)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw CryptoError.sealFailed
        }
        return encryptedPrefix + combined.base64EncodedString()
    }

    static func decrypt(_ value: String, using key: SymmetricKey) throws -> String {
        guard isEncrypted(value) else {
            throw CryptoError.notEncrypted
        }
        let base64 = String(value.dropFirst(encryptedPrefix.count))
        guard let combined = Data(base64Encoded: base64) else {
            throw CryptoError.malformed
        }
        let box = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(box, using: key)
        guard let string = String(data: plaintext, encoding: .utf8) else {
            throw CryptoError.decodingFailed
        }
        return string
    }
}

enum CryptoError: Error, CustomStringConvertible {
    case sealFailed
    case notEncrypted
    case malformed
    case decodingFailed

    var description: String {
        switch self {
        case .sealFailed:      "Failed to seal encrypted value"
        case .notEncrypted:    "Value is not encrypted"
        case .malformed:       "Encrypted value is malformed"
        case .decodingFailed:  "Failed to decode decrypted bytes as UTF-8"
        }
    }
}
