//
// SecurityManager.swift
// bitpoints.me
//
// Security management for Bluetooth mesh networking
// Ported from Android SecurityManager.kt
//

import Foundation
import CoreBluetooth

/// SecurityManager - Provides security controls and attack prevention
/// Implements rate limiting, RSSI gating, replay attack prevention, and malformed packet handling
final class SecurityManager: NSObject {
    
    // MARK: - Constants
    
    private let maxMessagesPerMinute = 60
    private let maxMessagesPerHour = 1000
    private let minRSSIThreshold: Int = -80 // dBm
    private let maxRSSIThreshold: Int = -30 // dBm
    private let suspiciousActivityThreshold = 10
    private let blockDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Security State
    
    private struct PeerSecurityInfo {
        var messageCount: Int = 0
        var lastMessageTime: Date = Date.distantPast
        var hourlyCount: Int = 0
        var lastHourReset: Date = Date()
        var suspiciousActivity: Int = 0
        var isBlocked: Bool = false
        var blockUntil: Date = Date.distantPast
        var averageRSSI: Double = -100.0
        var rssiSamples: [Double] = []
    }
    
    private struct SecurityEvent {
        let timestamp: Date
        let peerID: PeerID
        let eventType: SecurityEventType
        let severity: SecuritySeverity
        let details: String
    }
    
    enum SecurityEventType {
        case rateLimitExceeded
        case suspiciousRSSI
        case malformedPacket
        case replayAttack
        case suspiciousActivity
    }
    
    enum SecuritySeverity {
        case low
        case medium
        case high
        case critical
    }
    
    // MARK: - State Management
    
    private var peerSecurityInfo: [PeerID: PeerSecurityInfo] = [:]
    private var securityEvents: [SecurityEvent] = []
    private var securityQueue = DispatchQueue(label: "me.bitpoints.wallet.security", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Dependencies
    
    private weak var delegate: SecurityManagerDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Start cleanup timer
        startCleanupTimer()
        
        print("SecurityManager: Initialized")
    }
    
    // MARK: - Message Validation
    
    /// Validate incoming message
    func validateMessage(_ data: Data, from peerID: PeerID, rssi: Int) -> SecurityValidationResult {
        return securityQueue.sync {
            // Check if peer is blocked
            if isPeerBlocked(peerID) {
                logSecurityEvent(
                    peerID: peerID,
                    eventType: .rateLimitExceeded,
                    severity: .medium,
                    details: "Blocked peer attempted to send message"
                )
                return .blocked
            }
            
            // Check rate limits
            if !checkRateLimits(for: peerID) {
                blockPeer(peerID, duration: blockDuration)
                logSecurityEvent(
                    peerID: peerID,
                    eventType: .rateLimitExceeded,
                    severity: .high,
                    details: "Rate limit exceeded"
                )
                return .rateLimited
            }
            
            // Check RSSI
            if !validateRSSI(rssi, for: peerID) {
                logSecurityEvent(
                    peerID: peerID,
                    eventType: .suspiciousRSSI,
                    severity: .medium,
                    details: "Suspicious RSSI: \(rssi) dBm"
                )
                return .suspiciousRSSI
            }
            
            // Check packet format
            if !validatePacketFormat(data) {
                logSecurityEvent(
                    peerID: peerID,
                    eventType: .malformedPacket,
                    severity: .medium,
                    details: "Malformed packet received"
                )
                return .malformedPacket
            }
            
            // Update peer info
            updatePeerInfo(peerID, rssi: rssi)
            
            return .valid
        }
    }
    
    /// Check rate limits for peer
    private func checkRateLimits(for peerID: PeerID) -> Bool {
        let now = Date()
        var info = peerSecurityInfo[peerID] ?? PeerSecurityInfo()
        
        // Reset hourly count if needed
        if now.timeIntervalSince(info.lastHourReset) >= 3600 {
            info.hourlyCount = 0
            info.lastHourReset = now
        }
        
        // Check per-minute limit
        if now.timeIntervalSince(info.lastMessageTime) < 60 {
            if info.messageCount >= maxMessagesPerMinute {
                return false
            }
        } else {
            // Reset per-minute count
            info.messageCount = 0
        }
        
        // Check per-hour limit
        if info.hourlyCount >= maxMessagesPerHour {
            return false
        }
        
        // Update counts
        info.messageCount += 1
        info.hourlyCount += 1
        info.lastMessageTime = now
        
        peerSecurityInfo[peerID] = info
        
        return true
    }
    
    /// Validate RSSI
    private func validateRSSI(_ rssi: Int, for peerID: PeerID) -> Bool {
        // Check absolute RSSI limits
        if rssi < minRSSIThreshold || rssi > maxRSSIThreshold {
            return false
        }
        
        // Check for suspicious RSSI patterns
        var info = peerSecurityInfo[peerID] ?? PeerSecurityInfo()
        
        // Add RSSI sample
        info.rssiSamples.append(Double(rssi))
        
        // Keep only last 10 samples
        if info.rssiSamples.count > 10 {
            info.rssiSamples.removeFirst()
        }
        
        // Calculate average RSSI
        if info.rssiSamples.count >= 3 {
            info.averageRSSI = info.rssiSamples.reduce(0, +) / Double(info.rssiSamples.count)
            
            // Check for sudden RSSI changes (possible relay attack)
            let rssiChange = abs(Double(rssi) - info.averageRSSI)
            if rssiChange > 20 { // More than 20 dBm change
                info.suspiciousActivity += 1
                if info.suspiciousActivity >= suspiciousActivityThreshold {
                    return false
                }
            }
        }
        
        peerSecurityInfo[peerID] = info
        
        return true
    }
    
    /// Validate packet format
    private func validatePacketFormat(_ data: Data) -> Bool {
        // Check minimum packet size
        guard data.count >= 4 else {
            return false
        }
        
        // Check message type
        let messageType = data[0]
        guard MessageHandler.MessageType(rawValue: messageType) != nil else {
            return false
        }
        
        // Check TTL
        let ttl = data[1]
        guard ttl <= 7 && ttl >= 0 else {
            return false
        }
        
        // Check payload length
        let payloadLength = UInt16(data[2]) << 8 | UInt16(data[3])
        guard payloadLength <= 1024 && data.count >= 4 + Int(payloadLength) else {
            return false
        }
        
        return true
    }
    
    // MARK: - Peer Management
    
    /// Block peer
    private func blockPeer(_ peerID: PeerID, duration: TimeInterval) {
        var info = peerSecurityInfo[peerID] ?? PeerSecurityInfo()
        info.isBlocked = true
        info.blockUntil = Date().addingTimeInterval(duration)
        peerSecurityInfo[peerID] = info
        
        print("SecurityManager: Blocked peer \(peerID) for \(duration) seconds")
    }
    
    /// Check if peer is blocked
    private func isPeerBlocked(_ peerID: PeerID) -> Bool {
        guard let info = peerSecurityInfo[peerID] else {
            return false
        }
        
        if info.isBlocked {
            if Date() > info.blockUntil {
                // Unblock peer
                var updatedInfo = info
                updatedInfo.isBlocked = false
                updatedInfo.blockUntil = Date.distantPast
                peerSecurityInfo[peerID] = updatedInfo
                return false
            }
            return true
        }
        
        return false
    }
    
    /// Update peer information
    private func updatePeerInfo(_ peerID: PeerID, rssi: Int) {
        var info = peerSecurityInfo[peerID] ?? PeerSecurityInfo()
        info.lastMessageTime = Date()
        peerSecurityInfo[peerID] = info
    }
    
    // MARK: - Security Monitoring
    
    /// Log security event
    private func logSecurityEvent(peerID: PeerID, eventType: SecurityEventType, severity: SecuritySeverity, details: String) {
        let event = SecurityEvent(
            timestamp: Date(),
            peerID: peerID,
            eventType: eventType,
            severity: severity,
            details: details
        )
        
        securityEvents.append(event)
        
        // Keep only last 1000 events
        if securityEvents.count > 1000 {
            securityEvents.removeFirst(securityEvents.count - 1000)
        }
        
        print("SecurityManager: \(severity) - \(eventType) from \(peerID): \(details)")
        
        // Notify delegate
        DispatchQueue.main.async {
            self.delegate?.securityManager(self, didDetectEvent: event)
        }
    }
    
    /// Get security statistics
    func getSecurityStatistics() -> SecurityStatistics {
        return securityQueue.sync {
            let totalEvents = securityEvents.count
            let recentEvents = securityEvents.filter { 
                $0.timestamp > Date().addingTimeInterval(-3600) // Last hour
            }.count
            
            let blockedPeers = peerSecurityInfo.values.filter { $0.isBlocked }.count
            let suspiciousPeers = peerSecurityInfo.values.filter { $0.suspiciousActivity > 0 }.count
            
            return SecurityStatistics(
                totalEvents: totalEvents,
                recentEvents: recentEvents,
                blockedPeers: blockedPeers,
                suspiciousPeers: suspiciousPeers,
                activePeers: peerSecurityInfo.count
            )
        }
    }
    
    // MARK: - Cleanup
    
    /// Start cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupOldData()
        }
    }
    
    /// Clean up old data
    private func cleanupOldData() {
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago
        
        // Clean up old events
        securityEvents.removeAll { $0.timestamp < cutoffTime }
        
        // Reset suspicious activity for old peers
        for (peerID, info) in peerSecurityInfo {
            if info.lastMessageTime < cutoffTime {
                var updatedInfo = info
                updatedInfo.suspiciousActivity = 0
                updatedInfo.rssiSamples.removeAll()
                peerSecurityInfo[peerID] = updatedInfo
            }
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
}

// MARK: - Supporting Types

enum SecurityValidationResult {
    case valid
    case blocked
    case rateLimited
    case suspiciousRSSI
    case malformedPacket
}

struct SecurityStatistics {
    let totalEvents: Int
    let recentEvents: Int
    let blockedPeers: Int
    let suspiciousPeers: Int
    let activePeers: Int
}

// MARK: - Delegate Protocol

protocol SecurityManagerDelegate: AnyObject {
    func securityManager(_ manager: SecurityManager, didDetectEvent event: SecurityManager.SecurityEvent)
}
