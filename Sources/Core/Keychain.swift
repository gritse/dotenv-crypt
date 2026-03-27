import CryptoKit
import Foundation
import Security

enum Keychain {
    static let defaultService = "dotenv-crypt"
    static let defaultAccount = "encryption-key"

    static func saveKey(_ key: SymmetricKey, keychainPath: String? = nil) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        var query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      defaultService,
            kSecAttrAccount as String:      defaultAccount,
            kSecAttrDescription as String:  "dotenv-crypt key",
            kSecValueData as String:        keyData,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        if let path = keychainPath, let ref = openKeychain(path: path) {
            query[kSecUseKeychain as String] = ref // swiftlint:disable:this deprecated_attribute
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            throw KeychainError.alreadyExists
        }
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func loadKey(keychainPath: String? = nil) throws -> SymmetricKey {
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: defaultAccount,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        if let path = keychainPath, let ref = openKeychain(path: path) {
            query[kSecMatchSearchList as String] = [ref]
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status)
        }

        return SymmetricKey(data: data)
    }

    static func keyExists(keychainPath: String? = nil) -> Bool {
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: defaultAccount
        ]

        if let path = keychainPath, let ref = openKeychain(path: path) {
            query[kSecMatchSearchList as String] = [ref]
        }

        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func saveItem(_ data: Data, service: String, account: String, keychainPath: String? = nil) throws {
        var query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecAttrDescription as String:  "dotenv-crypt key",
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if let path = keychainPath, let ref = openKeychain(path: path) {
            query[kSecUseKeychain as String] = ref
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem { throw KeychainError.alreadyExists }
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func moveItem(service: String, account: String?, from fromPath: String?, to toPath: String) throws {
        // Load raw data from source
        var loadQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        if let account { loadQuery[kSecAttrAccount as String] = account }
        if let path = fromPath, let ref = openKeychain(path: path) {
            loadQuery[kSecMatchSearchList as String] = [ref]
        }

        var result: AnyObject?
        let loadStatus = SecItemCopyMatching(loadQuery as CFDictionary, &result)
        guard loadStatus == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(loadStatus)
        }

        // Save to destination
        var saveQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrDescription as String:  "dotenv-crypt key",
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if let account { saveQuery[kSecAttrAccount as String] = account }
        if let ref = openKeychain(path: toPath) {
            saveQuery[kSecUseKeychain as String] = ref
        }

        let saveStatus = SecItemAdd(saveQuery as CFDictionary, nil)
        if saveStatus == errSecDuplicateItem { throw KeychainError.alreadyExists }
        guard saveStatus == errSecSuccess else { throw KeychainError.saveFailed(saveStatus) }

        // Delete from source
        var deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let account { deleteQuery[kSecAttrAccount as String] = account }
        if let path = fromPath, let ref = openKeychain(path: path) {
            deleteQuery[kSecMatchSearchList as String] = [ref]
        }
        SecItemDelete(deleteQuery as CFDictionary)
    }

    static func updateDescription(_ description: String, service: String, account: String?, keychainPath: String? = nil) throws {
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let account { query[kSecAttrAccount as String] = account }
        if let path = keychainPath, let ref = openKeychain(path: path) {
            query[kSecMatchSearchList as String] = [ref]
        }

        let attrs: [String: Any] = [
            kSecAttrDescription as String: description
        ]

        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.updateFailed(status)
        }
    }

    static func deleteKey(keychainPath: String? = nil) throws {
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: defaultAccount
        ]

        if let path = keychainPath, let ref = openKeychain(path: path) {
            query[kSecMatchSearchList as String] = [ref]
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // SecKeychainOpen is deprecated but remains the only way to target a specific keychain file.
    private static func openKeychain(path: String) -> SecKeychain? {
        var ref: SecKeychain?
        SecKeychainOpen(path, &ref)
        return ref
    }
}

enum KeychainError: Error, CustomStringConvertible {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case alreadyExists
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)

    var description: String {
        switch self {
        case .saveFailed(let s):  "Failed to save key to Keychain (status \(s))"
        case .loadFailed(let s):  "Failed to load key from Keychain (status \(s))"
        case .deleteFailed(let s): "Failed to delete key from Keychain (status \(s))"
        case .updateFailed(let s): "Failed to update Keychain item (status \(s))"
        case .alreadyExists:      "Encryption key already exists in Keychain."
        }
    }
}
