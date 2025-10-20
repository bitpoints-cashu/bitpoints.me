//
// MessageHandler.swift
// bitpoints.me
//
// Message processing and routing for Bluetooth mesh networking
// Ported from Android MessageHandler.kt
//

import Foundation
import CoreBluetooth

/// MessageHandler - Processes incoming messages and handles routing
/// Implements message deduplication, TTL management, and type routing
final class MessageHandler: NSObject {
    
    // MARK: - Constants
    
    private let maxMessageAge: TimeInterval = 300 // 5 minutes
    private let maxDeduplicationCacheSize = 1000
    private let ttlDecrementValue: UInt8 = 1
    
    // MARK: - Message Types
    
    enum MessageType: UInt8 {
        case ecash = 0xE1
        case announce = 0xA1
        case sync = 0xS1
        case fragment = 0xF1
        case ack = 0x01
        case unknown = 0x00
    }
    
    // MARK: - Message State
    
    private struct ProcessedMessage {
        let messageId: String
        let timestamp: Date
        let sender: PeerID
        let type: MessageType
        let ttl: UInt8
    }
    
    // MARK: - State Management
    
    private var processedMessages: [String: ProcessedMessage] = [:]
    private var messageQueue = DispatchQueue(label: "me.bitpoints.wallet.message", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Dependencies
    
    private weak var delegate: MessageHandlerDelegate?
    private let connectionManager: ConnectionManager
    private let fragmentManager: FragmentManager
    
    // MARK: - Initialization
    
    init(connectionManager: ConnectionManager, fragmentManager: FragmentManager) {
        self.connectionManager = connectionManager
        self.fragmentManager = fragmentManager
        super.init()
        
        // Start cleanup timer
        startCleanupTimer()
        
        print("MessageHandler: Initialized")
    }
    
    // MARK: - Message Processing
    
    /// Process incoming message
    func processMessage(_ data: Data, from sender: PeerID, via relay: PeerID?) {
        messageQueue.async {
            do {
                let packet = try self.parsePacket(data)
                let messageId = self.generateMessageId(packet, sender: sender)
                
                // Check for duplicates
                if self.isDuplicateMessage(messageId) {
                    print("MessageHandler: Duplicate message \(messageId) from \(sender)")
                    return
                }
                
                // Check TTL
                if packet.ttl <= 0 {
                    print("MessageHandler: Message \(messageId) expired (TTL: \(packet.ttl))")
                    return
                }
                
                // Record processed message
                self.recordProcessedMessage(messageId: messageId, sender: sender, type: packet.type, ttl: packet.ttl)
                
                // Route based on message type
                try self.routeMessage(packet, from: sender, via: relay)
                
            } catch {
                print("MessageHandler: Error processing message from \(sender): \(error)")
            }
        }
    }
    
    /// Parse packet from raw data
    private func parsePacket(_ data: Data) throws -> BitchatPacket {
        guard data.count >= 4 else {
            throw MessageError.invalidPacketSize
        }
        
        let type = MessageType(rawValue: data[0]) ?? .unknown
        let ttl = data[1]
        let payloadLength = UInt16(data[2]) << 8 | UInt16(data[3])
        
        guard data.count >= 4 + Int(payloadLength) else {
            throw MessageError.invalidPayloadSize
        }
        
        let payload = data.subdata(in: 4..<4+Int(payloadLength))
        
        return BitchatPacket(
            type: type,
            ttl: ttl,
            payload: payload,
            timestamp: Date()
        )
    }
    
    /// Route message based on type
    private func routeMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        switch packet.type {
        case .ecash:
            try handleEcashMessage(packet, from: sender, via: relay)
        case .announce:
            try handleAnnounceMessage(packet, from: sender, via: relay)
        case .sync:
            try handleSyncMessage(packet, from: sender, via: relay)
        case .fragment:
            try handleFragmentMessage(packet, from: sender, via: relay)
        case .ack:
            try handleAckMessage(packet, from: sender, via: relay)
        case .unknown:
            print("MessageHandler: Unknown message type from \(sender)")
        }
    }
    
    // MARK: - Message Type Handlers
    
    /// Handle ecash message
    private func handleEcashMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        print("MessageHandler: Processing ecash message from \(sender)")
        
        // Parse ecash message
        let ecashMessage = try EcashMessage.fromData(packet.payload)
        
        // Check if message is for us
        if ecashMessage.recipientId == getMyPeerID() {
            // Deliver locally
            DispatchQueue.main.async {
                self.delegate?.messageHandler(self, didReceiveEcash: ecashMessage, from: sender)
            }
        } else {
            // Relay to other peers
            try relayMessage(packet, from: sender, via: relay)
        }
    }
    
    /// Handle announce message
    private func handleAnnounceMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        print("MessageHandler: Processing announce message from \(sender)")
        
        // Parse announce message
        let announceMessage = try IdentityAnnouncement.fromData(packet.payload)
        
        // Update peer info
        DispatchQueue.main.async {
            self.delegate?.messageHandler(self, didReceiveAnnounce: announceMessage, from: sender)
        }
        
        // Relay announce message
        try relayMessage(packet, from: sender, via: relay)
    }
    
    /// Handle sync message
    private func handleSyncMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        print("MessageHandler: Processing sync message from \(sender)")
        
        // Parse sync message
        let syncMessage = try RequestSyncPacket.fromData(packet.payload)
        
        // Handle sync request
        DispatchQueue.main.async {
            self.delegate?.messageHandler(self, didReceiveSync: syncMessage, from: sender)
        }
    }
    
    /// Handle fragment message
    private func handleFragmentMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        print("MessageHandler: Processing fragment message from \(sender)")
        
        // Delegate to fragment manager
        fragmentManager.processFragment(packet.payload, from: sender) { [weak self] completeMessage in
            if let message = completeMessage {
                // Process the complete message
                self?.processMessage(message, from: sender, via: relay)
            }
        }
    }
    
    /// Handle ack message
    private func handleAckMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        print("MessageHandler: Processing ack message from \(sender)")
        
        // Parse ack message
        let ackMessage = try DeliveryAck.fromData(packet.payload)
        
        DispatchQueue.main.async {
            self.delegate?.messageHandler(self, didReceiveAck: ackMessage, from: sender)
        }
    }
    
    // MARK: - Message Relaying
    
    /// Relay message to other peers
    private func relayMessage(_ packet: BitchatPacket, from sender: PeerID, via relay: PeerID?) throws {
        // Decrement TTL
        var relayPacket = packet
        relayPacket.ttl = max(0, packet.ttl - ttlDecrementValue)
        
        // Check if we should relay (TTL > 0)
        if relayPacket.ttl <= 0 {
            print("MessageHandler: Not relaying message - TTL expired")
            return
        }
        
        // Get active connections (excluding sender and relay)
        let activeConnections = connectionManager.getActiveConnections().filter { peerID in
            peerID != sender && peerID != relay
        }
        
        if activeConnections.isEmpty {
            print("MessageHandler: No active connections to relay to")
            return
        }
        
        // Serialize packet for relay
        let relayData = try serializePacket(relayPacket)
        
        // Send to all active connections
        for peerID in activeConnections {
            DispatchQueue.main.async {
                self.delegate?.messageHandler(self, shouldRelayMessage: relayData, to: peerID)
            }
        }
        
        print("MessageHandler: Relayed message to \(activeConnections.count) peers")
    }
    
    // MARK: - Message Creation
    
    /// Create ecash message
    func createEcashMessage(_ ecashMessage: EcashMessage, ttl: UInt8 = 7) throws -> Data {
        let payload = try ecashMessage.toData()
        let packet = BitchatPacket(
            type: .ecash,
            ttl: ttl,
            payload: payload,
            timestamp: Date()
        )
        return try serializePacket(packet)
    }
    
    /// Create announce message
    func createAnnounceMessage(_ announceMessage: IdentityAnnouncement, ttl: UInt8 = 3) throws -> Data {
        let payload = try announceMessage.toData()
        let packet = BitchatPacket(
            type: .announce,
            ttl: ttl,
            payload: payload,
            timestamp: Date()
        )
        return try serializePacket(packet)
    }
    
    /// Create ack message
    func createAckMessage(_ ackMessage: DeliveryAck) throws -> Data {
        let payload = try ackMessage.toData()
        let packet = BitchatPacket(
            type: .ack,
            ttl: 0, // ACKs don't get relayed
            payload: payload,
            timestamp: Date()
        )
        return try serializePacket(packet)
    }
    
    // MARK: - Serialization
    
    /// Serialize packet to data
    private func serializePacket(_ packet: BitchatPacket) throws -> Data {
        var data = Data()
        
        // Message type
        data.append(packet.type.rawValue)
        
        // TTL
        data.append(packet.ttl)
        
        // Payload length (2 bytes, big endian)
        let payloadLength = UInt16(packet.payload.count)
        data.append(UInt8(payloadLength >> 8))
        data.append(UInt8(payloadLength & 0xFF))
        
        // Payload
        data.append(packet.payload)
        
        return data
    }
    
    // MARK: - Deduplication
    
    /// Generate unique message ID
    private func generateMessageId(_ packet: BitchatPacket, sender: PeerID) -> String {
        let hash = packet.payload.sha256()
        return "\(sender.id)_\(hash.hexString)"
    }
    
    /// Check if message is duplicate
    private func isDuplicateMessage(_ messageId: String) -> Bool {
        return processedMessages[messageId] != nil
    }
    
    /// Record processed message
    private func recordProcessedMessage(messageId: String, sender: PeerID, type: MessageType, ttl: UInt8) {
        let processedMessage = ProcessedMessage(
            messageId: messageId,
            timestamp: Date(),
            sender: sender,
            type: type,
            ttl: ttl
        )
        
        processedMessages[messageId] = processedMessage
        
        // Cleanup if cache is too large
        if processedMessages.count > maxDeduplicationCacheSize {
            cleanupOldMessages()
        }
    }
    
    // MARK: - Cleanup
    
    /// Start cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupOldMessages()
        }
    }
    
    /// Clean up old messages
    private func cleanupOldMessages() {
        let cutoffTime = Date().addingTimeInterval(-maxMessageAge)
        
        let oldMessages = processedMessages.filter { _, message in
            message.timestamp < cutoffTime
        }
        
        for (messageId, _) in oldMessages {
            processedMessages.removeValue(forKey: messageId)
        }
        
        if !oldMessages.isEmpty {
            print("MessageHandler: Cleaned up \(oldMessages.count) old messages")
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

// MARK: - Delegate Protocol

protocol MessageHandlerDelegate: AnyObject {
    func messageHandler(_ handler: MessageHandler, didReceiveEcash message: EcashMessage, from sender: PeerID)
    func messageHandler(_ handler: MessageHandler, didReceiveAnnounce message: IdentityAnnouncement, from sender: PeerID)
    func messageHandler(_ handler: MessageHandler, didReceiveSync message: RequestSyncPacket, from sender: PeerID)
    func messageHandler(_ handler: MessageHandler, didReceiveAck message: DeliveryAck, from sender: PeerID)
    func messageHandler(_ handler: MessageHandler, shouldRelayMessage data: Data, to peerID: PeerID)
}

// MARK: - Errors

enum MessageError: Error {
    case invalidPacketSize
    case invalidPayloadSize
    case invalidMessageType
    case serializationFailed
    case deserializationFailed
}

// MARK: - Extensions

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    func sha256() -> Data {
        let hash = SHA256.hash(data: self)
        return Data(hash)
    }
}
