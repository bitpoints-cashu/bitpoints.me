//
// NoiseEncryptionService.swift
// bitpoints.me
//
// Ported from bitchat for cross-platform compatibility
//

import Foundation
import CryptoKit

/// Manages end-to-end encryption for Bitpoints using the Noise Protocol Framework.
/// Provides a high-level API for establishing secure channels between peers,
/// handling all cryptographic operations transparently.
final class NoiseEncryptionService {
    // Static identity key (persistent across sessions)
    private let staticIdentityKey: Curve25519.KeyAgreement.PrivateKey
    public let staticIdentityPublicKey: Curve25519.KeyAgreement.PublicKey

    // Ed25519 signing key (persistent across sessions)
    private let signingKey: Curve25519.Signing.PrivateKey
    public let signingPublicKey: Curve25519.Signing.PublicKey

    // Session manager
    private let sessionManager: NoiseSessionManager

    // Peer fingerprints (SHA256 hash of static public key)
    private var peerFingerprints: [PeerID: String] = [:]
    private var fingerprintToPeerID: [String: PeerID] = [:]

    // Thread safety
    private let serviceQueue = DispatchQueue(label: "me.bitpoints.wallet.noise.service", attributes: .concurrent)

    // Security components
    private let keychain: KeychainManagerProtocol

    // Session maintenance
    private var rekeyTimer: Timer?
    private let rekeyCheckInterval: TimeInterval = 60.0 // Check every minute

    // Callbacks
    private var onPeerAuthenticatedHandlers: [((String, String) -> Void)] = [] // Array of handlers for peer authentication
    var onHandshakeRequired: ((PeerID) -> Void)? // peerID needs handshake

    // Add a handler for peer authentication
    func addOnPeerAuthenticatedHandler(_ handler: @escaping (String, String) -> Void) {
        serviceQueue.async(flags: .barrier) { [weak self] in
            self?.onPeerAuthenticatedHandlers.append(handler)
        }
    }

    // Legacy support - setting this will add to the handlers array
    var onPeerAuthenticated: ((String, String) -> Void)? {
        get { nil } // Always return nil for backward compatibility
        set {
            if let handler = newValue {
                addOnPeerAuthenticatedHandler(handler)
            }
        }
    }

    init(keychain: KeychainManagerProtocol) {
        self.keychain = keychain

        // Load or create static identity key (ONLY from keychain)
        let loadedKey: Curve25519.KeyAgreement.PrivateKey

        // Try to load from keychain
        if let identityData = keychain.getIdentityKey(forKey: "noiseStaticKey"),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: identityData) {
            loadedKey = key
            print("NoiseEncryptionService: Loaded existing noise static key")
        }
        // If no identity exists, create new one
        else {
            loadedKey = Curve25519.KeyAgreement.PrivateKey()
            let keyData = loadedKey.rawRepresentation

            // Save to keychain
            let saved = keychain.saveIdentityKey(keyData, forKey: "noiseStaticKey")
            print("NoiseEncryptionService: Created new noise static key - \(saved ? "saved" : "failed to save")")
        }

        // Now assign the final value
        self.staticIdentityKey = loadedKey
        self.staticIdentityPublicKey = staticIdentityKey.publicKey

        // Load or create signing key pair
        let loadedSigningKey: Curve25519.Signing.PrivateKey

        // Try to load from keychain
        if let signingData = keychain.getIdentityKey(forKey: "ed25519SigningKey"),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: signingData) {
            loadedSigningKey = key
            print("NoiseEncryptionService: Loaded existing signing key")
        }
        // If no signing key exists, create new one
        else {
            loadedSigningKey = Curve25519.Signing.PrivateKey()
            let keyData = loadedSigningKey.rawRepresentation

            // Save to keychain
            let saved = keychain.saveIdentityKey(keyData, forKey: "ed25519SigningKey")
            print("NoiseEncryptionService: Created new signing key - \(saved ? "saved" : "failed to save")")
        }

        // Now assign the signing keys
        self.signingKey = loadedSigningKey
        self.signingPublicKey = signingKey.publicKey

        // Initialize session manager
        self.sessionManager = NoiseSessionManager(localStaticKey: staticIdentityKey, keychain: keychain)

        // Set up session callbacks
        sessionManager.onSessionEstablished = { [weak self] peerID, remoteStaticKey in
            self?.handleSessionEstablished(peerID: peerID, remoteStaticKey: remoteStaticKey)
        }

        // Start session maintenance timer
        startRekeyTimer()
    }

    // MARK: - Public Interface

    /// Get our static public key for sharing
    func getStaticPublicKeyData() -> Data {
        return staticIdentityPublicKey.rawRepresentation
    }

    /// Get our signing public key for sharing
    func getSigningPublicKeyData() -> Data {
        return signingPublicKey.rawRepresentation
    }

    /// Get our identity fingerprint
    func getIdentityFingerprint() -> String {
        staticIdentityPublicKey.rawRepresentation.sha256Fingerprint()
    }

    /// Get peer's public key data
    func getPeerPublicKeyData(_ peerID: PeerID) -> Data? {
        return sessionManager.getRemoteStaticKey(for: peerID)?.rawRepresentation
    }

    /// Clear persistent identity (for panic mode)
    func clearPersistentIdentity() {
        // Clear from keychain
        let deletedStatic = keychain.deleteIdentityKey(forKey: "noiseStaticKey")
        let deletedSigning = keychain.deleteIdentityKey(forKey: "ed25519SigningKey")
        print("NoiseEncryptionService: Panic mode activated - identity cleared - static: \(deletedStatic), signing: \(deletedSigning)")
        // Stop rekey timer
        stopRekeyTimer()
    }

    /// Sign data with our Ed25519 signing key
    func signData(_ data: Data) -> Data? {
        do {
            let signature = try signingKey.signature(for: data)
            return signature
        } catch {
            print("NoiseEncryptionService: Failed to sign data: \(error)")
            return nil
        }
    }

    /// Verify signature with a peer's Ed25519 public key
    func verifySignature(_ signature: Data, for data: Data, publicKey: Data) -> Bool {
        do {
            let signingPublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            return signingPublicKey.isValidSignature(signature, for: data)
        } catch {
            print("NoiseEncryptionService: Failed to verify signature: \(error)")
            return false
        }
    }

    // MARK: - Handshake Management

    /// Initiate a Noise handshake with a peer
    func initiateHandshake(with peerID: PeerID) throws -> Data {
        // Validate peer ID
        guard peerID.isValid else {
            print("NoiseEncryptionService: Invalid peer ID: \(peerID)")
            throw NoiseSessionError.handshakeFailed
        }

        print("NoiseEncryptionService: Starting handshake with \(peerID)")

        // Return raw handshake data without wrapper
        // The Noise protocol handles its own message format
        let handshakeData = try sessionManager.initiateHandshake(with: peerID)
        return handshakeData
    }

    /// Process an incoming handshake message
    func processHandshakeMessage(from peerID: PeerID, message: Data) throws -> Data? {
        // Validate peer ID
        guard peerID.isValid else {
            print("NoiseEncryptionService: Invalid peer ID: \(peerID)")
            throw NoiseSessionError.handshakeFailed
        }

        // Validate message size
        guard message.count <= 1024 else {
            print("NoiseEncryptionService: Message too large: \(message.count) bytes")
            throw NoiseSessionError.handshakeFailed
        }

        // For handshakes, we process the raw data directly without NoiseMessage wrapper
        // The Noise protocol handles its own message format
        let responsePayload = try sessionManager.handleIncomingHandshake(from: peerID, message: message)

        // Return raw response without wrapper
        return responsePayload
    }

    /// Check if we have an established session with a peer
    func hasEstablishedSession(with peerID: PeerID) -> Bool {
        return sessionManager.getSession(for: peerID)?.isEstablished() ?? false
    }

    /// Check if we have a session (established or handshaking) with a peer
    func hasSession(with peerID: PeerID) -> Bool {
        return sessionManager.getSession(for: peerID) != nil
    }

    // MARK: - Encryption/Decryption

    /// Encrypt data for a specific peer
    func encrypt(_ data: Data, for peerID: PeerID) throws -> Data {
        // Validate message size
        guard data.count <= 65536 else {
            throw NoiseSessionError.handshakeFailed
        }

        // Check if we have an established session
        guard hasEstablishedSession(with: peerID) else {
            // Signal that handshake is needed
            onHandshakeRequired?(peerID)
            throw NoiseSessionError.handshakeFailed
        }

        return try sessionManager.encrypt(data, for: peerID)
    }

    /// Decrypt data from a specific peer
    func decrypt(_ data: Data, from peerID: PeerID) throws -> Data {
        // Validate message size
        guard data.count <= 65536 else {
            throw NoiseSessionError.handshakeFailed
        }

        // Check if we have an established session
        guard hasEstablishedSession(with: peerID) else {
            throw NoiseSessionError.handshakeFailed
        }

        return try sessionManager.decrypt(data, from: peerID)
    }

    // MARK: - Peer Management

    /// Get fingerprint for a peer
    func getPeerFingerprint(_ peerID: PeerID) -> String? {
        return serviceQueue.sync {
            return peerFingerprints[peerID]
        }
    }

    func clearEphemeralStateForPanic() {
        sessionManager.removeAllSessions()
        serviceQueue.sync(flags: .barrier) {
            peerFingerprints.removeAll()
            fingerprintToPeerID.removeAll()
        }
    }

    // MARK: - Private Helpers

    private func handleSessionEstablished(peerID: PeerID, remoteStaticKey: Curve25519.KeyAgreement.PublicKey) {
        // Calculate fingerprint
        let fingerprint = remoteStaticKey.rawRepresentation.sha256Fingerprint()

        // Store fingerprint mapping
        serviceQueue.sync(flags: .barrier) {
            peerFingerprints[peerID] = fingerprint
            fingerprintToPeerID[fingerprint] = peerID
        }

        // Log security event
        print("NoiseEncryptionService: Handshake completed with \(peerID)")

        // Notify all handlers about authentication
        serviceQueue.async { [weak self] in
            self?.onPeerAuthenticatedHandlers.forEach { handler in
                handler(peerID.id, fingerprint)
            }
        }
    }

    // MARK: - Session Maintenance

    private func startRekeyTimer() {
        rekeyTimer = Timer.scheduledTimer(withTimeInterval: rekeyCheckInterval, repeats: true) { [weak self] _ in
            self?.checkSessionsForRekey()
        }
    }

    private func stopRekeyTimer() {
        rekeyTimer?.invalidate()
        rekeyTimer = nil
    }

    private func checkSessionsForRekey() {
        let sessionsNeedingRekey = sessionManager.getSessionsNeedingRekey()

        for (peerID, needsRekey) in sessionsNeedingRekey where needsRekey {
            // Attempt to rekey the session
            do {
                try sessionManager.initiateRekey(for: peerID)
                print("NoiseEncryptionService: Key rotation initiated for peer: \(peerID)")

                // Signal that handshake is needed
                onHandshakeRequired?(peerID)
            } catch {
                print("NoiseEncryptionService: Failed to initiate rekey for peer: \(peerID) - \(error)")
            }
        }
    }

    deinit {
        stopRekeyTimer()
    }
}
