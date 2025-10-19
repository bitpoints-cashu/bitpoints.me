//
// NoiseProtocol.swift
// bitpoints.me
//
// Simplified Noise Protocol implementation for cross-platform compatibility
//

import Foundation
import CryptoKit

// MARK: - Constants and Types

/// Supported Noise handshake patterns.
enum NoisePattern {
    case XX  // Most versatile, mutual authentication
}

enum NoiseRole {
    case initiator
    case responder
}

enum NoiseSessionState {
    case uninitialized
    case handshaking
    case established
}

enum NoiseSessionError: Error {
    case invalidState
    case notEstablished
    case sessionNotFound
    case alreadyEstablished
    case handshakeFailed
    case encryptionFailed
    case decryptionFailed
}

// MARK: - Noise Cipher State

class NoiseCipherState {
    private var key: SymmetricKey
    private var nonce: UInt64 = 0

    init(key: SymmetricKey) {
        self.key = key
    }

    func encrypt(plaintext: Data) throws -> Data {
        let nonceData = withUnsafeBytes(of: nonce.bigEndian) { Data($0) }
        let nonceBytes = nonceData.suffix(12) // Use last 12 bytes for ChaCha20-Poly1305

        let sealedBox = try ChaChaPoly.seal(plaintext, using: key, nonce: ChaChaPoly.Nonce(data: nonceBytes))
        nonce += 1

        return sealedBox.combined
    }

    func decrypt(ciphertext: Data) throws -> Data {
        let nonceData = withUnsafeBytes(of: nonce.bigEndian) { Data($0) }
        let nonceBytes = nonceData.suffix(12) // Use last 12 bytes for ChaCha20-Poly1305

        let sealedBox = try ChaChaPoly.SealedBox(combined: ciphertext)
        let plaintext = try ChaChaPoly.open(sealedBox, using: key, nonce: ChaChaPoly.Nonce(data: nonceBytes))
        nonce += 1

        return plaintext
    }

    func clearSensitiveData() {
        // Clear the key from memory
        key = SymmetricKey(data: Data(repeating: 0, count: 32))
    }
}

// MARK: - Noise Handshake State

class NoiseHandshakeState {
    private let role: NoiseRole
    private let pattern: NoisePattern
    private let localStaticKey: Curve25519.KeyAgreement.PrivateKey
    private let remoteStaticKey: Curve25519.KeyAgreement.PublicKey?
    private let keychain: KeychainManagerProtocol

    private var ephemeralKey: Curve25519.KeyAgreement.PrivateKey?
    private var remoteEphemeralKey: Curve25519.KeyAgreement.PublicKey?
    private var handshakeHash: Data
    private var handshakeComplete = false

    init(role: NoiseRole, pattern: NoisePattern, keychain: KeychainManagerProtocol, localStaticKey: Curve25519.KeyAgreement.PrivateKey, remoteStaticKey: Curve25519.KeyAgreement.PublicKey?) {
        self.role = role
        self.pattern = pattern
        self.keychain = keychain
        self.localStaticKey = localStaticKey
        self.remoteStaticKey = remoteStaticKey

        // Initialize handshake hash with protocol name
        let protocolName = "Noise_XX_25519_ChaChaPoly_SHA256"
        self.handshakeHash = Data(protocolName.utf8)
    }

    func writeMessage() throws -> Data {
        switch pattern {
        case .XX:
            return try writeXXMessage()
        }
    }

    func readMessage(_ message: Data) throws {
        switch pattern {
        case .XX:
            try readXXMessage(message)
        }
    }

    private func writeXXMessage() throws -> Data {
        if role == .initiator {
            // First message: e
            ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
            let ephemeralPublicKey = ephemeralKey!.publicKey

            // Update handshake hash
            handshakeHash = SHA256.hash(data: handshakeHash + ephemeralPublicKey.rawRepresentation)

            return ephemeralPublicKey.rawRepresentation
        } else {
            // Second message: e, ee, s, es
            guard let remoteEphemeralData = ephemeralKey?.publicKey.rawRepresentation else {
                throw NoiseSessionError.handshakeFailed
            }

            ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
            let ephemeralPublicKey = ephemeralKey!.publicKey

            // Update handshake hash
            handshakeHash = SHA256.hash(data: handshakeHash + ephemeralPublicKey.rawRepresentation)

            // Calculate shared secrets
            let ee = try ephemeralKey!.sharedSecretFromKeyAgreement(with: remoteEphemeralKey!)
            let es = try ephemeralKey!.sharedSecretFromKeyAgreement(with: remoteStaticKey!)

            // Derive keys
            let ck = SHA256.hash(data: handshakeHash + ee.rawRepresentation)
            let k1 = SHA256.hash(data: ck + es.rawRepresentation)

            // Encrypt static key
            let key = SymmetricKey(data: k1)
            let nonce = Data(repeating: 0, count: 12)
            let sealedBox = try ChaChaPoly.seal(localStaticKey.publicKey.rawRepresentation, using: key, nonce: ChaChaPoly.Nonce(data: nonce))

            handshakeHash = SHA256.hash(data: handshakeHash + sealedBox.combined)

            return ephemeralPublicKey.rawRepresentation + sealedBox.combined
        }
    }

    private func readXXMessage(_ message: Data) throws {
        if role == .initiator {
            // Second message: e, ee, s, es
            guard message.count >= 32 else {
                throw NoiseSessionError.handshakeFailed
            }

            let remoteEphemeralData = message.prefix(32)
            remoteEphemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralData)

            // Update handshake hash
            handshakeHash = SHA256.hash(data: handshakeHash + remoteEphemeralData)

            // Calculate shared secrets
            let ee = try ephemeralKey!.sharedSecretFromKeyAgreement(with: remoteEphemeralKey!)
            let es = try ephemeralKey!.sharedSecretFromKeyAgreement(with: remoteStaticKey!)

            // Derive keys
            let ck = SHA256.hash(data: handshakeHash + ee.rawRepresentation)
            let k1 = SHA256.hash(data: ck + es.rawRepresentation)

            // Decrypt static key
            let key = SymmetricKey(data: k1)
            let nonce = Data(repeating: 0, count: 12)
            let sealedBox = try ChaChaPoly.SealedBox(combined: message.dropFirst(32))
            let decryptedStaticKey = try ChaChaPoly.open(sealedBox, using: key, nonce: ChaChaPoly.Nonce(data: nonce))

            handshakeHash = SHA256.hash(data: handshakeHash + message)

            // Third message: s, se
            let se = try localStaticKey.sharedSecretFromKeyAgreement(with: remoteEphemeralKey!)
            let k2 = SHA256.hash(data: ck + se.rawRepresentation)

            let encryptKey = SymmetricKey(data: k2)
            let encryptNonce = Data(repeating: 0, count: 12)
            let encryptedStaticKey = try ChaChaPoly.seal(localStaticKey.publicKey.rawRepresentation, using: encryptKey, nonce: ChaChaPoly.Nonce(data: encryptNonce))

            handshakeHash = SHA256.hash(data: handshakeHash + encryptedStaticKey.combined)

            handshakeComplete = true
        } else {
            // First message: e
            guard message.count == 32 else {
                throw NoiseSessionError.handshakeFailed
            }

            remoteEphemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: message)

            // Update handshake hash
            handshakeHash = SHA256.hash(data: handshakeHash + message)
        }
    }

    func isHandshakeComplete() -> Bool {
        return handshakeComplete
    }

    func getTransportCiphers() throws -> (send: NoiseCipherState, receive: NoiseCipherState) {
        guard handshakeComplete else {
            throw NoiseSessionError.handshakeFailed
        }

        // Derive final transport keys
        let k1 = SHA256.hash(data: handshakeHash + Data(repeating: 0, count: 32))
        let k2 = SHA256.hash(data: handshakeHash + Data(repeating: 1, count: 32))

        let sendKey = SymmetricKey(data: k1)
        let receiveKey = SymmetricKey(data: k2)

        return (NoiseCipherState(key: sendKey), NoiseCipherState(key: receiveKey))
    }

    func getRemoteStaticPublicKey() -> Curve25519.KeyAgreement.PublicKey? {
        return remoteStaticKey
    }

    func getHandshakeHash() -> Data {
        return handshakeHash
    }
}

// MARK: - Secure Noise Session

class SecureNoiseSession: NoiseSession {
    private var messageCount: UInt64 = 0
    private let maxMessages: UInt64 = 1000 // Rekey after 1000 messages

    func needsRenegotiation() -> Bool {
        return messageCount >= maxMessages
    }

    override func encrypt(_ plaintext: Data) throws -> Data {
        messageCount += 1
        return try super.encrypt(plaintext)
    }

    override func decrypt(_ ciphertext: Data) throws -> Data {
        messageCount += 1
        return try super.decrypt(ciphertext)
    }
}
