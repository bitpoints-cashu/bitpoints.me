//
// PacketProcessor.swift
// bitpoints.me
//
// Packet processing and routing for Bluetooth mesh networking
// Ported from Android PacketProcessor.kt
//

import Foundation

/// PacketProcessor - Handles packet routing and processing decisions
/// Implements local delivery vs relay decision, TTL decrement, and loop prevention
final class PacketProcessor: NSObject {
    
    // MARK: - Constants
    
    private let maxTTL: UInt8 = 7
    private let minTTL: UInt8 = 1
    private let loopPreventionWindow: TimeInterval = 60 // 1 minute
    
    // MARK: - Processing State
    
    private struct ProcessedPacket {
        let packetId: String
        let timestamp: Date
        let sender: PeerID
        let ttl: UInt8
    }
    
    // MARK: - State Management
    
    private var processedPackets: [String: ProcessedPacket] = [:]
    private var processingQueue = DispatchQueue(label: "me.bitpoints.wallet.packet.processor", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Dependencies
    
    private weak var delegate: PacketProcessorDelegate?
    private let connectionManager: ConnectionManager
    private let messageHandler: MessageHandler
    
    // MARK: - Initialization
    
    init(connectionManager: ConnectionManager, messageHandler: MessageHandler) {
        self.connectionManager = connectionManager
        self.messageHandler = messageHandler
        super.init()
        
        // Start cleanup timer
        startCleanupTimer()
        
        print("PacketProcessor: Initialized")
    }
    
    // MARK: - Packet Processing
    
    /// Process incoming packet
    func processPacket(_ data: Data, from sender: PeerID, via relay: PeerID?) {
        processingQueue.async {
            do {
                let packet = try self.parsePacket(data)
                let packetId = self.generatePacketId(packet, sender: sender)
                
                // Check for loops
                if self.isLoopPacket(packetId) {
                    print("PacketProcessor: Dropping loop packet \(packetId)")
                    return
                }
                
                // Check TTL
                if packet.ttl <= 0 {
                    print("PacketProcessor: Packet \(packetId) expired (TTL: \(packet.ttl))")
                    return
                }
                
                // Record processed packet
                self.recordProcessedPacket(packetId: packetId, sender: sender, ttl: packet.ttl)
                
                // Make routing decision
                let routingDecision = try self.makeRoutingDecision(packet, from: sender, via: relay)
                
                // Execute routing decision
                try self.executeRoutingDecision(routingDecision, packet: packet, from: sender, via: relay)
                
            } catch {
                print("PacketProcessor: Error processing packet from \(sender): \(error)")
            }
        }
    }
    
    /// Parse packet from raw data
    private func parsePacket(_ data: Data) throws -> BitchatPacket {
        guard data.count >= 4 else {
            throw PacketError.invalidPacketSize
        }
        
        let type = MessageHandler.MessageType(rawValue: data[0]) ?? .unknown
        let ttl = data[1]
        let payloadLength = UInt16(data[2]) << 8 | UInt16(data[3])
        
        guard data.count >= 4 + Int(payloadLength) else {
            throw PacketError.invalidPayloadSize
        }
        
        let payload = data.subdata(in: 4..<4+Int(payloadLength))
        
        return BitchatPacket(
            type: type,
            ttl: ttl,
            payload: payload,
            timestamp: Date()
        )
    }
    
    /// Make routing decision
    private func makeRoutingDecision(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws -> RoutingDecision {
        // Check if packet is for us
        if try isPacketForUs(packet) {
            return .deliverLocally
        }
        
        // Check if we should relay
        if shouldRelayPacket(packet, from: sender, via: relay) {
            return .relay
        }
        
        return .drop
    }
    
    /// Check if packet is for us
    private func isPacketForUs(_ packet: BitchatPacket) throws -> Bool {
        switch packet.type {
        case .ecash:
            let ecashMessage = try EcashMessage.fromData(packet.payload)
            return ecashMessage.recipientId == getMyPeerID()
        case .announce:
            // Announcements are for everyone
            return true
        case .sync:
            // Sync requests are for us
            return true
        case .ack:
            // ACKs are for us
            return true
        case .fragment:
            // Fragments need to be reassembled first
            return true
        case .unknown:
            return false
        }
    }
    
    /// Check if we should relay packet
    private func shouldRelayPacket(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) -> Bool {
        // Don't relay if TTL is too low
        if packet.ttl <= 1 {
            return false
        }
        
        // Don't relay ACKs
        if packet.type == .ack {
            return false
        }
        
        // Don't relay if we're the original sender
        if packet.type == .ecash {
            do {
                let ecashMessage = try EcashMessage.fromData(packet.payload)
                if ecashMessage.senderId == getMyPeerID() {
                    return false
                }
            } catch {
                return false
            }
        }
        
        // Check if we have active connections to relay to
        let activeConnections = connectionManager.getActiveConnections()
        let relayTargets = activeConnections.filter { peerID in
            peerID != sender && peerID != relay
        }
        
        return !relayTargets.isEmpty
    }
    
    /// Execute routing decision
    private func executeRoutingDecision(_ decision: RoutingDecision, packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        switch decision {
        case .deliverLocally:
            try deliverPacketLocally(packet, from: sender)
        case .relay:
            try relayPacket(packet, from: sender, via: relay)
        case .drop:
            print("PacketProcessor: Dropping packet")
        }
    }
    
    /// Deliver packet locally
    private func deliverPacketLocally(_ packet: BitchatPacket, from sender: PeerID) throws {
        print("PacketProcessor: Delivering packet locally from \(sender)")
        
        // Delegate to message handler
        messageHandler.processMessage(packet.payload, from: sender, via: nil)
    }
    
    /// Relay packet to other peers
    private func relayPacket(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        // Decrement TTL
        var relayPacket = packet
        relayPacket.ttl = max(minTTL, packet.ttl - 1)
        
        // Get active connections (excluding sender and relay)
        let activeConnections = connectionManager.getActiveConnections().filter { peerID in
            peerID != sender && peerID != relay
        }
        
        if activeConnections.isEmpty {
            print("PacketProcessor: No active connections to relay to")
            return
        }
        
        // Serialize packet for relay
        let relayData = try serializePacket(relayPacket)
        
        // Send to all active connections
        for peerID in activeConnections {
            DispatchQueue.main.async {
                self.delegate?.packetProcessor(self, shouldRelayPacket: relayData, to: peerID)
            }
        }
        
        print("PacketProcessor: Relayed packet to \(activeConnections.count) peers")
    }
    
    // MARK: - Packet Creation
    
    /// Create packet for sending
    func createPacket(type: MessageHandler.MessageType, payload: Data, ttl: UInt8 = maxTTL) throws -> Data {
        let packet = BitchatPacket(
            type: type,
            ttl: ttl,
            payload: payload,
            timestamp: Date()
        )
        return try serializePacket(packet)
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
    
    // MARK: - Loop Prevention
    
    /// Generate unique packet ID
    private func generatePacketId(_ packet: BitchatPacket, sender: PeerID) -> String {
        let hash = packet.payload.sha256()
        return "\(sender.id)_\(hash.hexString)"
    }
    
    /// Check if packet is a loop
    private func isLoopPacket(_ packetId: String) -> Bool {
        return processedPackets[packetId] != nil
    }
    
    /// Record processed packet
    private func recordProcessedPacket(packetId: String, sender: PeerID, ttl: UInt8) {
        let processedPacket = ProcessedPacket(
            packetId: packetId,
            timestamp: Date(),
            sender: sender,
            ttl: ttl
        )
        
        processedPackets[packetId] = processedPacket
    }
    
    // MARK: - Cleanup
    
    /// Start cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupOldPackets()
        }
    }
    
    /// Clean up old packets
    private func cleanupOldPackets() {
        let cutoffTime = Date().addingTimeInterval(-loopPreventionWindow)
        
        let oldPackets = processedPackets.filter { _, packet in
            packet.timestamp < cutoffTime
        }
        
        for (packetId, _) in oldPackets {
            processedPackets.removeValue(forKey: packetId)
        }
        
        if !oldPackets.isEmpty {
            print("PacketProcessor: Cleaned up \(oldPackets.count) old packets")
        }
    }
    
    // MARK: - Statistics
    
    /// Get processing statistics
    func getProcessingStatistics() -> ProcessingStatistics {
        return processingQueue.sync {
            let totalPackets = processedPackets.count
            let recentPackets = processedPackets.values.filter { 
                $0.timestamp > Date().addingTimeInterval(-300) // Last 5 minutes
            }.count
            
            return ProcessingStatistics(
                totalPackets: totalPackets,
                recentPackets: recentPackets,
                activeConnections: connectionManager.getActiveConnections().count
            )
        }
    }
    
    // MARK: - Helper Methods
    
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

enum RoutingDecision {
    case deliverLocally
    case relay
    case drop
}

struct ProcessingStatistics {
    let totalPackets: Int
    let recentPackets: Int
    let activeConnections: Int
}

// MARK: - Delegate Protocol

protocol PacketProcessorDelegate: AnyObject {
    func packetProcessor(_ processor: PacketProcessor, shouldRelayPacket data: Data, to peerID: PeerID)
}

// MARK: - Errors

enum PacketError: Error {
    case invalidPacketSize
    case invalidPayloadSize
    case invalidRoutingDecision
    case serializationFailed
}
