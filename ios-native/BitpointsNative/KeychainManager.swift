//
// KeychainManager.swift
// bitpoints.me
//
// Ported from bitchat for cross-platform compatibility
//

import Foundation
import Security

protocol KeychainManagerProtocol {
    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool
    func getIdentityKey(forKey key: String) -> Data?
    func deleteIdentityKey(forKey key: String) -> Bool
    func deleteAllKeychainData() -> Bool

    func secureClear(_ data: inout Data)
    func secureClear(_ string: inout String)

    func verifyIdentityKeyExists() -> Bool
}

final class KeychainManager: KeychainManagerProtocol {
    // Use consistent service name for all keychain items
    private let service = "me.bitpoints.wallet"

    // MARK: - Identity Keys

    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool {
        let fullKey = "identity_\(key)"
        let result = saveData(keyData, forKey: fullKey)
        print("Keychain: Saved identity key '\(key)' - \(result ? "success" : "failed")")
        return result
    }

    func getIdentityKey(forKey key: String) -> Data? {
        let fullKey = "identity_\(key)"
        return retrieveData(forKey: fullKey)
    }

    func deleteIdentityKey(forKey key: String) -> Bool {
        let result = delete(forKey: "identity_\(key)")
        print("Keychain: Deleted identity key '\(key)' - \(result ? "success" : "failed")")
        return result
    }

    // MARK: - Generic Operations

    private func saveData(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first to ensure clean state
        _ = delete(forKey: key)

        // Build base query
        var base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrLabel as String: "bitpoints-\(key)"
        ]

        let status = SecItemAdd(base as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func retrieveData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return data
    }

    private func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func deleteAllKeychainData() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Secure Clear

    func secureClear(_ data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
    }

    func secureClear(_ string: inout String) {
        string = String(repeating: " ", count: string.count)
        string = ""
    }

    func verifyIdentityKeyExists() -> Bool {
        return getIdentityKey(forKey: "noiseStaticKey") != nil
    }
}
