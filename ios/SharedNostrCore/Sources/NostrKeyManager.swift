import Foundation
import Security
import secp256k1

public final class NostrKeyManager {
    public static let shared = NostrKeyManager()

    private let keychainService = "bitpoints.watch.nostr"
    private let privateKeyAccount = "nostr.privatekey"

    private init() {}

    public func loadOrCreateKeypair() throws -> (privateKeyHex: String, publicKeyHex: String) {
        if let existing = try? loadPrivateKeyHex() {
            let pub = try publicKey(from: existing)
            return (existing, pub)
        }
        let newKey = try secp256k1.Signing.PrivateKey()
        let privHex = newKey.dataRepresentation.hexEncodedString()
        let pubHex = newKey.publicKey.dataRepresentation.hexEncodedString()
        try savePrivateKeyHex(privHex)
        return (privHex, pubHex)
    }

    public func publicKey(from privateKeyHex: String) throws -> String {
        guard let data = Data(hexString: privateKeyHex) else {
            throw NSError(domain: "NostrKeyManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid hex"])
        }
        let priv = try secp256k1.Signing.PrivateKey(rawRepresentation: data)
        return priv.publicKey.dataRepresentation.hexEncodedString()
    }

    private func loadPrivateKeyHex() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data.hexEncodedString()
        }
        return nil
    }

    private func savePrivateKeyHex(_ hex: String) throws {
        guard let data = Data(hexString: hex) else {
            throw NSError(domain: "NostrKeyManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid hex to save"])
        }
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: privateKeyAccount
        ] as CFDictionary)
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecValueData as String: data
        ] as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "NostrKeyManager", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain save failed"])
        }
    }
}

public extension Data {
    init?(hexString: String) {
        var data = Data(capacity: hexString.count / 2)

        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard nextIndex <= hexString.endIndex else { return nil }
            let byteString = hexString[index..<nextIndex]
            guard let num = UInt8(byteString, radix: 16) else { return nil }
            data.append(num)
            index = nextIndex
        }
        self = data
    }

    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

