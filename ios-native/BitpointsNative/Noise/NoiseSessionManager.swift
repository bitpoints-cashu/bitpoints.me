//
// NoiseSessionManager.swift
// bitpoints.me
//
// Noise Protocol session management for multiple peers
// Ported from Android NoiseSessionManager.kt
//

import Foundation

/// NoiseSessionManager - Manages multiple Noise Protocol sessions
/// Handles session lifecycle, expiration, and rekeying
final class NoiseSessionManager: NSObject {
    
    // MARK: - Constants
    
    private let sessionTimeout: TimeInterval = 300 // 5 minutes
    private let rekeyInterval: TimeInterval = 3600 // 1 hour
    private let maxSessions = 50
    
    // MARK: - Session State
    
    private struct SessionInfo {
        let session: NoiseSession
        let createdAt: Date
        var lastUsed: Date
        var rekeyCount: Int
    }
    
    // MARK: - State Management
    
    private var sessions: [PeerID: SessionInfo] = [:]
    private var sessionQueue = DispatchQueue(label: "me.bitpoints.wallet.noise.sessions", attributes: .concurrent)
    private var cleanupTimer: Timer?
    private let keychain: KeychainManagerProtocol
    
    // MARK: - Initialization
    
    init(keychain: KeychainManagerProtocol) {
        self.keychain = keychain
        super.init()
        
        // Start cleanup timer
        startCleanupTimer()
        
        print("NoiseSessionManager: Initialized")
    }
    
    // MARK: - Session Management
    
    /// Get or create session for peer
    func getSession(for peerID: PeerID) -> NoiseSession {
        return sessionQueue.sync {
            if let sessionInfo = sessions[peerID] {
                // Update last used time
                var updatedInfo = sessionInfo
                updatedInfo.lastUsed = Date()
                sessions[peerID] = updatedInfo
                
                return sessionInfo.session
            } else {
                // Create new session
                let session = NoiseSession(peerID: peerID, keychain: keychain)
                let sessionInfo = SessionInfo(
                    session: session,
                    createdAt: Date(),
                    lastUsed: Date(),
                    rekeyCount: 0
                )
                
                sessions[peerID] = sessionInfo
                
                print("NoiseSessionManager: Created new session for peer \(peerID)")
                return session
            }
        }
    }
    
    /// Start handshake for peer
    func startHandshake(for peerID: PeerID) throws -> Data {
        let session = getSession(for: peerID)
        return try session.startHandshake()
    }
    
    /// Process handshake message
    func processHandshakeMessage(_ message: Data, from peerID: PeerID) throws -> Data? {
        let session = getSession(for: peerID)
        return try session.processHandshakeMessage(message)
    }
    
    /// Encrypt message for peer
    func encrypt(_ plaintext: Data, for peerID: PeerID) throws -> Data {
        let session = getSession(for: peerID)
        return try session.encrypt(plaintext)
    }
    
    /// Decrypt message from peer
    func decrypt(_ ciphertext: Data, from peerID: PeerID) throws -> Data {
        let session = getSession(for: peerID)
        return try session.decrypt(ciphertext)
    }
    
    /// Check if session is established for peer
    func isSessionEstablished(for peerID: PeerID) -> Bool {
        return sessionQueue.sync {
            guard let sessionInfo = sessions[peerID] else { return false }
            return sessionInfo.session.sessionState == .established
        }
    }
    
    /// Get session state for peer
    func getSessionState(for peerID: PeerID) -> NoiseSessionState {
        return sessionQueue.sync {
            guard let sessionInfo = sessions[peerID] else { return .uninitialized }
            return sessionInfo.session.sessionState
        }
    }
    
    // MARK: - Session Cleanup
    
    /// Remove session for peer
    func removeSession(for peerID: PeerID) {
        sessionQueue.async(flags: .barrier) {
            if let sessionInfo = self.sessions[peerID] {
                sessionInfo.session.clearSensitiveData()
                self.sessions.removeValue(forKey: peerID)
                print("NoiseSessionManager: Removed session for peer \(peerID)")
            }
        }
    }
    
    /// Start cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupExpiredSessions()
        }
    }
    
    /// Clean up expired sessions
    private func cleanupExpiredSessions() {
        sessionQueue.async(flags: .barrier) {
            let cutoffTime = Date().addingTimeInterval(-self.sessionTimeout)
            
            let expiredSessions = self.sessions.filter { _, sessionInfo in
                sessionInfo.lastUsed < cutoffTime
            }
            
            for (peerID, sessionInfo) in expiredSessions {
                sessionInfo.session.clearSensitiveData()
                self.sessions.removeValue(forKey: peerID)
            }
            
            if !expiredSessions.isEmpty {
                print("NoiseSessionManager: Cleaned up \(expiredSessions.count) expired sessions")
            }
            
            // Limit total sessions
            if self.sessions.count > self.maxSessions {
                self.limitSessions()
            }
        }
    }
    
    /// Limit number of sessions
    private func limitSessions() {
        let sortedSessions = sessions.sorted { $0.value.lastUsed < $1.value.lastUsed }
        let sessionsToRemove = sortedSessions.prefix(sessions.count - maxSessions)
        
        for (peerID, sessionInfo) in sessionsToRemove {
            sessionInfo.session.clearSensitiveData()
            sessions.removeValue(forKey: peerID)
        }
        
        print("NoiseSessionManager: Limited sessions to \(maxSessions)")
    }
    
    // MARK: - Statistics
    
    /// Get session statistics
    func getSessionStatistics() -> SessionStatistics {
        return sessionQueue.sync {
            let totalSessions = sessions.count
            let establishedSessions = sessions.values.filter { 
                $0.session.sessionState == .established 
            }.count
            let handshakingSessions = sessions.values.filter { 
                $0.session.sessionState == .handshaking 
            }.count
            
            return SessionStatistics(
                totalSessions: totalSessions,
                establishedSessions: establishedSessions,
                handshakingSessions: handshakingSessions,
                successRate: totalSessions > 0 ? Double(establishedSessions) / Double(totalSessions) : 0.0
            )
        }
    }
    
    // MARK: - Cleanup
    
    /// Clear all sessions
    func clearAllSessions() {
        sessionQueue.async(flags: .barrier) {
            for (_, sessionInfo) in self.sessions {
                sessionInfo.session.clearSensitiveData()
            }
            self.sessions.removeAll()
            print("NoiseSessionManager: Cleared all sessions")
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
        clearAllSessions()
    }
}

// MARK: - Supporting Types

struct SessionStatistics {
    let totalSessions: Int
    let establishedSessions: Int
    let handshakingSessions: Int
    let successRate: Double
}