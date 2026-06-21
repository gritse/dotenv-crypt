import CryptoKit
import Darwin
import Foundation

/// Manages per-.env "unlock" records that temporarily suppress the Touch ID prompt.
///
/// Records live in `/tmp`, encrypted with the same AES-256-GCM key used for .env values. Integrity
/// and binding are enforced via GCM additional authenticated data (AAD): the absolute path, a
/// SHA-256 of the file's current contents, and the current boot-session UUID. If any of these
/// differ at read time — file moved, file edited, or machine rebooted — `openRaw` fails and the
/// record is treated as absent.
///
/// Expiry uses a monotonic clock (`CLOCK_MONOTONIC_RAW`), never wall-clock, so rewinding the system
/// date cannot extend a window. The monotonic counter resets on reboot, which the boot-session UUID
/// binding independently catches.
enum UnlockStore {
    private struct Record: Codable {
        let deadlineMonotonicNs: UInt64
        let minutes: Int
        let createdWallClock: String  // human-readable, display only — never used for security
    }

    // MARK: - Paths

    /// Canonical absolute path used identically by writer and readers so records match.
    static func absolutePath(for file: String) -> String {
        URL(fileURLWithPath: file).resolvingSymlinksInPath().path
    }

    private static func recordURL(forEnv absPath: String) -> URL {
        let digest = SHA256.hash(data: Data(absPath.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return URL(fileURLWithPath: "/tmp/dotenv-crypt-unlock-\(hex).bin")
    }

    // MARK: - Time & boot session

    private static func nowMonotonicNs() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    }

    private static func bootSessionUUID() -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown-boot-session"
        }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buf, &size, nil, 0) == 0 else {
            return "unknown-boot-session"
        }
        return String(cString: buf)
    }

    private static func contentHashHex(of content: Data) -> String {
        let digest = SHA256.hash(data: content)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// AAD binds the record to a specific file path, its exact contents, and the current boot.
    private static func aad(absPath: String, contentHash: String) -> Data {
        Data("\(absPath)\n\(contentHash)\n\(bootSessionUUID())".utf8)
    }

    // MARK: - Read / write

    /// Creates an unlock record valid for `minutes`, bound to the exact `content` bytes provided.
    /// Overwrites any existing record for this file.
    static func write(envURL: URL, content: Data, minutes: Int, key: SymmetricKey) throws {
        let absPath = absolutePath(for: envURL.path)
        let contentHash = contentHashHex(of: content)

        let deadline = nowMonotonicNs() + UInt64(minutes) * 60 * 1_000_000_000
        let record = Record(
            deadlineMonotonicNs: deadline,
            minutes: minutes,
            createdWallClock: ISO8601DateFormatter().string(from: Date())
        )
        let plaintext = try JSONEncoder().encode(record)
        let combined = try Crypto.sealRaw(plaintext, using: key, aad: aad(absPath: absPath, contentHash: contentHash))

        let url = recordURL(forEnv: absPath)
        try combined.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// True if a valid, unexpired unlock record exists for this file under the current boot and the
    /// given `content` bytes. The caller must pass the exact bytes it will go on to decrypt, so the
    /// hash check and the use operate on one snapshot (no TOCTOU). Lazily deletes the record on
    /// expiry. Any failure (missing/tampered/mismatched) → false.
    static func isUnlocked(envURL: URL, content: Data, key: SymmetricKey) -> Bool {
        let absPath = absolutePath(for: envURL.path)
        let url = recordURL(forEnv: absPath)
        let contentHash = contentHashHex(of: content)

        guard let combined = try? Data(contentsOf: url),
              let plaintext = try? Crypto.openRaw(combined, using: key, aad: aad(absPath: absPath, contentHash: contentHash)),
              let record = try? JSONDecoder().decode(Record.self, from: plaintext) else {
            return false
        }

        if nowMonotonicNs() < record.deadlineMonotonicNs {
            return true
        }
        try? FileManager.default.removeItem(at: url)
        return false
    }

    // MARK: - Clearing

    /// Deletes the unlock record for a single file. Returns true if a record was removed.
    @discardableResult
    static func clear(envURL: URL) -> Bool {
        let url = recordURL(forEnv: absolutePath(for: envURL.path))
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        try? FileManager.default.removeItem(at: url)
        return true
    }

    /// Deletes every unlock record in /tmp. Returns the count removed.
    @discardableResult
    static func clearAll() -> Int {
        let fm = FileManager.default
        let tmp = URL(fileURLWithPath: "/tmp")
        guard let entries = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) else {
            return 0
        }
        var count = 0
        for entry in entries where entry.lastPathComponent.hasPrefix("dotenv-crypt-unlock-") && entry.pathExtension == "bin" {
            if (try? fm.removeItem(at: entry)) != nil { count += 1 }
        }
        return count
    }

    // MARK: - Gate

    /// Skips Touch ID if the file is currently unlocked for these exact `content` bytes; otherwise
    /// prompts as usual. Pass the same bytes you will decrypt to avoid a check/use race.
    static func requireTouchIDUnlessUnlocked(envURL: URL, content: Data, key: SymmetricKey, reason: String) throws {
        if isUnlocked(envURL: envURL, content: content, key: key) { return }
        try Auth.requireTouchID(reason: reason)
    }
}
