//
// NoiseProtocol.swift
// bitpoints.me
//
// Complete Noise Protocol implementation for cross-platform compatibility
// Ported from BitChat's implementation with Android compatibility
//

import Foundation
import CryptoKit

// MARK: - Constants and Types

/// Supported Noise handshake patterns
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
    case failed
}

enum NoiseSessionError: Error {
    case invalidState
    case notEstablished
    case sessionNotFound
    case alreadyEstablished
    case handshakeFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case invalidMessage
    case protocolViolation
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
    private var handshakeStep = 0
    
    // XX pattern has 3 steps: e, ee+s, se
    private let maxHandshakeSteps = 3
    
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
    
    // MARK: - Handshake Methods
    
    /// Start handshake as initiator
    func startHandshake() throws -> Data {
        guard role == .initiator else {
            throw NoiseSessionError.invalidState
        }
        
        // Generate ephemeral key
        ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        
        // Step 1: Send ephemeral public key
        let ephemeralPublicKey = ephemeralKey!.publicKey.rawRepresentation
        
        // Mix hash with ephemeral public key
        handshakeHash = mixHash(handshakeHash, ephemeralPublicKey)
        
        handshakeStep = 1
        
        return ephemeralPublicKey
    }
    
    /// Process handshake message
    func processHandshakeMessage(_ message: Data) throws -> Data? {
        handshakeStep += 1
        
        switch handshakeStep {
        case 1:
            // Step 1: Receive ephemeral public key
            guard message.count == 32 else {
                throw NoiseSessionError.invalidMessage
            }
            
            remoteEphemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: message)
            
            // Mix hash with remote ephemeral public key
            handshakeHash = mixHash(handshakeHash, message)
            
            if role == .responder {
                // Generate our ephemeral key
                ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
                let ephemeralPublicKey = ephemeralKey!.publicKey.rawRepresentation
                
                // Mix hash with our ephemeral public key
                handshakeHash = mixHash(handshakeHash, ephemeralPublicKey)
                
                return ephemeralPublicKey
            }
            
        case 2:
            // Step 2: Key exchange and static key exchange
            guard let remoteEphemeralKey = remoteEphemeralKey,
                  let ephemeralKey = ephemeralKey else {
                throw NoiseSessionError.invalidState
            }
            
            // Perform key exchange
            let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: remoteEphemeralKey)
            
            // Mix key with shared secret
            handshakeHash = mixKey(handshakeHash, sharedSecret.withUnsafeBytes { Data($0) })
            
            if role == .initiator {
                // Send our static public key
                let staticPublicKey = localStaticKey.publicKey.rawRepresentation
                handshakeHash = mixHash(handshakeHash, staticPublicKey)
                return staticPublicKey
            } else {
                // Receive remote static public key
                guard message.count == 32 else {
                    throw NoiseSessionError.invalidMessage
                }
                
                let remoteStaticKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: message)
                
                // Perform static key exchange
                let staticSharedSecret = try localStaticKey.sharedSecretFromKeyAgreement(with: remoteStaticKey)
                
                // Mix key with static shared secret
                handshakeHash = mixKey(handshakeHash, staticSharedSecret.withUnsafeBytes { Data($0) })
                
                // Send our static public key
                let staticPublicKey = localStaticKey.publicKey.rawRepresentation
                handshakeHash = mixHash(handshakeHash, staticPublicKey)
                return staticPublicKey
            }
            
        case 3:
            // Step 3: Final key exchange
            guard let remoteEphemeralKey = remoteEphemeralKey,
                  let ephemeralKey = ephemeralKey else {
                throw NoiseSessionError.invalidState
            }
            
            // Perform final key exchange
            let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: remoteEphemeralKey)
            
            // Mix key with shared secret
            handshakeHash = mixKey(handshakeHash, sharedSecret.withUnsafeBytes { Data($0) })
            
            // Handshake complete
            handshakeComplete = true
            
        default:
            throw NoiseSessionError.protocolViolation
        }
        
        return nil
    }
    
    /// Get encryption keys after handshake completion
    func getEncryptionKeys() throws -> (encryptKey: SymmetricKey, decryptKey: SymmetricKey) {
        guard handshakeComplete else {
            throw NoiseSessionError.handshakeFailed
        }
        
        // Derive encryption keys from handshake hash
        let encryptKeyData = handshakeHash.prefix(32)
        let decryptKeyData = handshakeHash.suffix(32)
        
        let encryptKey = SymmetricKey(data: encryptKeyData)
        let decryptKey = SymmetricKey(data: decryptKeyData)
        
        return (encryptKey, decryptKey)
    }
    
    // MARK: - Helper Methods
    
    /// Mix hash with data (HKDF expand)
    private func mixHash(_ hash: Data, _ data: Data) -> Data {
        var combined = hash
        combined.append(data)
        return SHA256.hash(data: combined).withUnsafeBytes { Data($0) }
    }
    
    /// Mix key with shared secret
    private func mixKey(_ hash: Data, _ sharedSecret: Data) -> Data {
        // Use HKDF to derive new key material
        let info = Data("Noise_XX_25519_ChaChaPoly_SHA256".utf8)
        let salt = hash
        
        // Simple HKDF implementation
        let prk = HMAC<SHA256>.authenticationCode(for: sharedSecret, using: SymmetricKey(data: salt))
        let infoData = info + Data([0x01]) // HKDF counter
        let okm = HMAC<SHA256>.authenticationCode(for: infoData, using: SymmetricKey(data: prk))
        
        return okm.withUnsafeBytes { Data($0) }
    }
}

// MARK: - Noise Session

class NoiseSession {
    private let peerID: PeerID
    private var state: NoiseSessionState
    private var handshakeState: NoiseHandshakeState?
    private var encryptCipher: NoiseCipherState?
    private var decryptCipher: NoiseCipherState?
    private let keychain: KeychainManagerProtocol
    
    init(peerID: PeerID, keychain: KeychainManagerProtocol) {
        self.peerID = peerID
        self.state = .uninitialized
        self.keychain = keychain
    }
    
    // MARK: - Session Management
    
    /// Start handshake as initiator
    func startHandshake() throws -> Data {
        guard state == .uninitialized else {
            throw NoiseSessionError.invalidState
        }
        
        state = .handshaking
        
        // Get or generate local static key
        let localStaticKey = try getOrGenerateStaticKey()
        
        // Create handshake state
        handshakeState = NoiseHandshakeState(
            role: .initiator,
            pattern: .XX,
            keychain: keychain,
            localStaticKey: localStaticKey,
            remoteStaticKey: nil
        )
        
        return try handshakeState!.startHandshake()
    }
    
    /// Process handshake message
    func processHandshakeMessage(_ message: Data) throws -> Data? {
        guard state == .handshaking,
              let handshakeState = handshakeState else {
            throw NoiseSessionError.invalidState
        }
        
        let response = try handshakeState.processHandshakeMessage(message)
        
        // Check if handshake is complete
        if handshakeState.handshakeComplete {
            try completeHandshake()
        }
        
        return response
    }
    
    /// Complete handshake and establish encryption
    private func completeHandshake() throws {
        guard let handshakeState = handshakeState else {
            throw NoiseSessionError.invalidState
        }
        
        let (encryptKey, decryptKey) = try handshakeState.getEncryptionKeys()
        
        encryptCipher = NoiseCipherState(key: encryptKey)
        decryptCipher = NoiseCipherState(key: decryptKey)
        
        state = .established
        
        print("NoiseSession: Handshake completed for peer \(peerID)")
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt message
    func encrypt(_ plaintext: Data) throws -> Data {
        guard state == .established,
              let encryptCipher = encryptCipher else {
            throw NoiseSessionError.notEstablished
        }
        
        return try encryptCipher.encrypt(plaintext: plaintext)
    }
    
    /// Decrypt message
    func decrypt(_ ciphertext: Data) throws -> Data {
        guard state == .established,
              let decryptCipher = decryptCipher else {
            throw NoiseSessionError.notEstablished
        }
        
        return try decryptCipher.decrypt(ciphertext: ciphertext)
    }
    
    // MARK: - Helper Methods
    
    /// Get or generate static key
    private func getOrGenerateStaticKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        let keyTag = "noise_static_key"
        
        // Try to load existing key
        if let keyData = keychain.get(key: keyTag),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData) {
            return key
        }
        
        // Generate new key
        let key = Curve25519.KeyAgreement.PrivateKey()
        let keyData = key.rawRepresentation
        
        // Store in keychain
        keychain.set(key: keyTag, value: keyData)
        
        return key
    }
    
    /// Get session state
    var sessionState: NoiseSessionState {
        return state
    }
    
    /// Clear sensitive data
    func clearSensitiveData() {
        encryptCipher?.clearSensitiveData()
        decryptCipher?.clearSensitiveData()
        encryptCipher = nil
        decryptCipher = nil
        handshakeState = nil
        state = .uninitialized
    }
}
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
