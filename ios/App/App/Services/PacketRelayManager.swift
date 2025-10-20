//
// PacketRelayManager.swift
// bitpoints.me
//
// Multi-hop relay management for Bluetooth mesh networking
// Ported from Android PacketRelayManager.kt
//

import Foundation

/// PacketRelayManager - Manages multi-hop relay functionality
/// Implements relay decision algorithm, bandwidth management, and relay tracking
final class PacketRelayManager: NSObject {
    
    // MARK: - Constants
    
    private let maxRelayHops = 7
    private let minRelayTTL: UInt8 = 2
    private let relayDecisionThreshold: Double = 0.3 // 30% chance to relay
    private let bandwidthLimit: Int = 1000 // bytes per second per peer
    private let relayTrackingWindow: TimeInterval = 300 // 5 minutes
    
    // MARK: - Relay State
    
    private struct RelayInfo {
        let packetId: String
        let timestamp: Date
        let sender: PeerID
        let relayCount: Int
        let bandwidthUsed: Int
    }
    
    private struct PeerRelayStats {
        var totalRelays: Int = 0
        var bandwidthUsed: Int = 0
        var lastRelayTime: Date = Date.distantPast
        var relayRate: Double = 0.0
    }
    
    // MARK: - State Management
    
    private var relayHistory: [String: RelayInfo] = [:]
    private var peerStats: [PeerID: PeerRelayStats] = [:]
    private var relayQueue = DispatchQueue(label: "me.bitpoints.wallet.relay", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Dependencies
    
    private weak var delegate: PacketRelayManagerDelegate?
    private let connectionManager: ConnectionManager
    private let packetProcessor: PacketProcessor
    
    // MARK: - Initialization
    
    init(connectionManager: ConnectionManager, packetProcessor: PacketProcessor) {
        self.connectionManager = connectionManager
        self.packetProcessor = packetProcessor
        super.init()
        
        // Start cleanup timer
        startCleanupTimer()
        
        print("PacketRelayManager: Initialized")
    }
    
    // MARK: - Relay Decision
    
    /// Decide whether to relay a packet
    func shouldRelayPacket(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) -> Bool {
        return relayQueue.sync {
            // Check basic relay conditions
            guard packet.ttl >= minRelayTTL else {
                print("PacketRelayManager: TTL too low (\(packet.ttl)), not relaying")
                return false
            }
            
            // Check hop count
            let hopCount = maxRelayHops - Int(packet.ttl)
            guard hopCount < maxRelayHops else {
                print("PacketRelayManager: Max hops reached (\(hopCount)), not relaying")
                return false
            }
            
            // Check if we're the original sender
            if isOriginalSender(packet) {
                print("PacketRelayManager: We are original sender, not relaying")
                return false
            }
            
            // Check bandwidth limits
            if !checkBandwidthLimits(for: sender) {
                print("PacketRelayManager: Bandwidth limit exceeded for \(sender)")
                return false
            }
            
            // Make probabilistic relay decision
            let relayDecision = makeProbabilisticRelayDecision(packet, from: sender)
            
            if relayDecision {
                recordRelayDecision(packet, from: sender)
            }
            
            return relayDecision
        }
    }
    
    /// Check if we are the original sender
    private func isOriginalSender(_ packet: BitchatPacket) -> Bool {
        switch packet.type {
        case .ecash:
            do {
                let ecashMessage = try EcashMessage.fromData(packet.payload)
                return ecashMessage.senderId == getMyPeerID()
            } catch {
                return false
            }
        case .announce:
            // Check if announcement is from us
            do {
                let announceMessage = try IdentityAnnouncement.fromData(packet.payload)
                return announceMessage.peerID == getMyPeerID()
            } catch {
                return false
            }
        default:
            return false
        }
    }
    
    /// Check bandwidth limits for peer
    private func checkBandwidthLimits(for peerID: PeerID) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60) // Last minute
        
        // Reset bandwidth if window has passed
        if peerStats[peerID]?.lastRelayTime ?? Date.distantPast < windowStart {
            peerStats[peerID]?.bandwidthUsed = 0
        }
        
        let currentBandwidth = peerStats[peerID]?.bandwidthUsed ?? 0
        return currentBandwidth < bandwidthLimit
    }
    
    /// Make probabilistic relay decision
    private func makeProbabilisticRelayDecision(_ packet: BitchatPacket, from sender: PeerID) -> Bool {
        // Base relay probability
        var relayProbability = relayDecisionThreshold
        
        // Adjust based on TTL (higher TTL = more likely to relay)
        let ttlFactor = Double(packet.ttl) / Double(maxRelayHops)
        relayProbability *= (0.5 + ttlFactor)
        
        // Adjust based on peer relay history
        if let stats = peerStats[sender] {
            let recentRelays = stats.totalRelays
            if recentRelays > 10 {
                // Reduce probability for peers that relay frequently
                relayProbability *= 0.7
            } else if recentRelays < 3 {
                // Increase probability for peers that don't relay much
                relayProbability *= 1.3
            }
        }
        
        // Adjust based on network density
        let activeConnections = connectionManager.getActiveConnections().count
        if activeConnections > 5 {
            // Reduce probability in dense networks
            relayProbability *= 0.8
        } else if activeConnections < 3 {
            // Increase probability in sparse networks
            relayProbability *= 1.2
        }
        
        // Clamp probability between 0.1 and 0.9
        relayProbability = max(0.1, min(0.9, relayProbability))
        
        // Make random decision
        let randomValue = Double.random(in: 0...1)
        let shouldRelay = randomValue < relayProbability
        
        print("PacketRelayManager: Relay decision for \(sender): \(shouldRelay) (prob: \(relayProbability))")
        
        return shouldRelay
    }
    
    /// Record relay decision
    private func recordRelayDecision(_ packet: BitchatPacket, from sender: PeerID) {
        let packetId = generatePacketId(packet, sender: sender)
        let hopCount = maxRelayHops - Int(packet.ttl)
        
        let relayInfo = RelayInfo(
            packetId: packetId,
            timestamp: Date(),
            sender: sender,
            relayCount: hopCount,
            bandwidthUsed: packet.payload.count
        )
        
        relayHistory[packetId] = relayInfo
        
        // Update peer statistics
        var stats = peerStats[sender] ?? PeerRelayStats()
        stats.totalRelays += 1
        stats.bandwidthUsed += packet.payload.count
        stats.lastRelayTime = Date()
        peerStats[sender] = stats
    }
    
    // MARK: - Relay Execution
    
    /// Execute packet relay
    func executeRelay(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) {
        relayQueue.async {
            do {
                // Decrement TTL
                var relayPacket = packet
                relayPacket.ttl = max(1, packet.ttl - 1)
                
                // Get relay targets
                let relayTargets = self.getRelayTargets(excluding: [sender, relay].compactMap { $0 })
                
                if relayTargets.isEmpty {
                    print("PacketRelayManager: No relay targets available")
                    return
                }
                
                // Serialize packet
                let relayData = try self.serializePacket(relayPacket)
                
                // Send to relay targets
                for target in relayTargets {
                    DispatchQueue.main.async {
                        self.delegate?.packetRelayManager(self, shouldRelayPacket: relayData, to: target)
                    }
                }
                
                print("PacketRelayManager: Relayed packet to \(relayTargets.count) peers")
                
            } catch {
                print("PacketRelayManager: Error executing relay: \(error)")
            }
        }
    }
    
    /// Get relay targets (excluding specified peers)
    private func getRelayTargets(excluding excludedPeers: [PeerID]) -> [PeerID] {
        let activeConnections = connectionManager.getActiveConnections()
        return activeConnections.filter { peerID in
            !excludedPeers.contains(peerID)
        }
    }
    
    /// Serialize packet to data
    private func serializePacket(_ packet: BitchatPacket) throws -> Data {
        var data = Data()
        
        // Message type (1 byte)
        data.append(packet.type.rawValue)
        
        // TTL (1 byte)
        data.append(packet.ttl)
        
        // Payload length (2 bytes, big endian)
        let payloadLength = UInt16(packet.payload.count)
        data.append(UInt8(payloadLength >> 8))
        data.append(UInt8(payloadLength & 0xFF))
        
        // Payload
        data.append(packet.payload)
        
        return data
    }
    
    // MARK: - Relay Optimization
    
    /// Optimize relay decisions based on network conditions
    func optimizeRelayDecisions() {
        relayQueue.async(flags: .barrier) {
            let now = Date()
            let activeConnections = self.connectionManager.getActiveConnections().count
            
            // Adjust relay probability based on network density
            if activeConnections > 8 {
                // Dense network - reduce relay probability
                self.adjustRelayProbability(factor: 0.8)
            } else if activeConnections < 3 {
                // Sparse network - increase relay probability
                self.adjustRelayProbability(factor: 1.2)
            }
            
            // Clean up old relay history
            self.cleanupOldRelayHistory()
            
            // Update peer relay rates
            self.updatePeerRelayRates()
        }
    }
    
    /// Adjust relay probability for all peers
    private func adjustRelayProbability(factor: Double) {
        for (peerID, _) in peerStats {
            peerStats[peerID]?.relayRate *= factor
        }
    }
    
    /// Update peer relay rates
    private func updatePeerRelayRates() {
        let now = Date()
        let windowStart = now.addingTimeInterval(-300) // Last 5 minutes
        
        for (peerID, stats) in peerStats {
            let recentRelays = relayHistory.values.filter { relayInfo in
                relayInfo.sender == peerID && relayInfo.timestamp > windowStart
            }.count
            
            peerStats[peerID]?.relayRate = Double(recentRelays) / 300.0 // Relays per second
        }
    }
    
    // MARK: - Cleanup
    
    /// Start cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupOldRelayHistory()
        }
    }
    
    /// Clean up old relay history
    private func cleanupOldRelayHistory() {
        let cutoffTime = Date().addingTimeInterval(-relayTrackingWindow)
        
        let oldRelays = relayHistory.filter { _, relayInfo in
            relayInfo.timestamp < cutoffTime
        }
        
        for (packetId, _) in oldRelays {
            relayHistory.removeValue(forKey: packetId)
        }
        
        if !oldRelays.isEmpty {
            print("PacketRelayManager: Cleaned up \(oldRelays.count) old relay records")
        }
    }
    
    // MARK: - Statistics
    
    /// Get relay statistics
    func getRelayStatistics() -> RelayStatistics {
        return relayQueue.sync {
            let totalRelays = relayHistory.count
            let recentRelays = relayHistory.values.filter { 
                $0.timestamp > Date().addingTimeInterval(-300) // Last 5 minutes
            }.count
            
            let activePeers = peerStats.count
            let totalBandwidth = peerStats.values.reduce(0) { $0 + $1.bandwidthUsed }
            
            return RelayStatistics(
                totalRelays: totalRelays,
                recentRelays: recentRelays,
                activePeers: activePeers,
                totalBandwidth: totalBandwidth,
                averageRelayRate: activePeers > 0 ? Double(recentRelays) / Double(activePeers) : 0.0
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate packet ID
    private func generatePacketId(_ packet: BitchatPacket, sender: PeerID) -> String {
        let hash = packet.payload.sha256()
        return "\(sender.id)_\(hash.hexString)"
    }
    
    /// Get my peer ID
    private func getMyPeerID() -> PeerID {
        // This should be injected or retrieved from a service
        // For now, return a placeholder
        return PeerID(publicKey: Data())
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
}

// MARK: - Supporting Types

struct RelayStatistics {
    let totalRelays: Int
    let recentRelays: Int
    let activePeers: Int
    let totalBandwidth: Int
    let averageRelayRate: Double
}

// MARK: - Delegate Protocol

protocol PacketRelayManagerDelegate: AnyObject {
    func packetRelayManager(_ manager: PacketRelayManager, shouldRelayPacket data: Data, to peerID: PeerID)
}
