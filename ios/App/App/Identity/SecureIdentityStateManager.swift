//
// SecureIdentityStateManager.swift
// bitpoints.me
//
// Ported from bitchat for cross-platform compatibility
//

import Foundation
import CryptoKit

protocol SecureIdentityStateManagerProtocol {
    func getOrCreateIdentity() -> (noiseKey: Curve25519.KeyAgreement.PrivateKey, signingKey: Curve25519.Signing.PrivateKey)
    func clearIdentity()
    func getIdentityFingerprint() -> String
}

final class SecureIdentityStateManager: SecureIdentityStateManagerProtocol {
    private let keychain: KeychainManagerProtocol

    init(keychain: KeychainManagerProtocol) {
        self.keychain = keychain
    }

    func getOrCreateIdentity() -> (noiseKey: Curve25519.KeyAgreement.PrivateKey, signingKey: Curve25519.Signing.PrivateKey) {
        // Try to load existing keys
        if let noiseKeyData = keychain.getIdentityKey(forKey: "noiseStaticKey"),
           let signingKeyData = keychain.getIdentityKey(forKey: "ed25519SigningKey"),
           let noiseKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: noiseKeyData),
           let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: signingKeyData) {
            print("SecureIdentityStateManager: Loaded existing identity")
            return (noiseKey, signingKey)
        }

        // Create new identity
        print("SecureIdentityStateManager: Creating new identity")
        let noiseKey = Curve25519.KeyAgreement.PrivateKey()
        let signingKey = Curve25519.Signing.PrivateKey()

        // Save to keychain
        let noiseSaved = keychain.saveIdentityKey(noiseKey.rawRepresentation, forKey: "noiseStaticKey")
        let signingSaved = keychain.saveIdentityKey(signingKey.rawRepresentation, forKey: "ed25519SigningKey")

        print("SecureIdentityStateManager: Identity saved - noise: \(noiseSaved), signing: \(signingSaved)")

        return (noiseKey, signingKey)
    }

    func clearIdentity() {
        print("SecureIdentityStateManager: Clearing identity")
        let noiseDeleted = keychain.deleteIdentityKey(forKey: "noiseStaticKey")
        let signingDeleted = keychain.deleteIdentityKey(forKey: "ed25519SigningKey")
        print("SecureIdentityStateManager: Identity cleared - noise: \(noiseDeleted), signing: \(signingDeleted)")
    }

    func getIdentityFingerprint() -> String {
        let (noiseKey, _) = getOrCreateIdentity()
        return noiseKey.publicKey.rawRepresentation.sha256Fingerprint()
    }
}
