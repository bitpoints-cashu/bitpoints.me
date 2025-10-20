//
// BitchatPacket.swift
// bitpoints.me
//
// Binary packet format for Bluetooth mesh networking
// Ported from Android BinaryProtocol.kt
//

import Foundation

/// BitchatPacket - Binary packet format for mesh networking
struct BitchatPacket {
    let type: MessageHandler.MessageType
    var ttl: UInt8
    let payload: Data
    let timestamp: Date
    
    init(type: MessageHandler.MessageType, ttl: UInt8, payload: Data, timestamp: Date = Date()) {
        self.type = type
        self.ttl = ttl
        self.payload = payload
        self.timestamp = timestamp
    }
}

// MARK: - Serialization

extension BitchatPacket {
    /// Serialize packet to binary data
    func toData() throws -> Data {
        var data = Data()
        
        // Message type (1 byte)
        data.append(type.rawValue)
        
        // TTL (1 byte)
        data.append(ttl)
        
        // Payload length (2 bytes, big endian)
        let payloadLength = UInt16(payload.count)
        data.append(UInt8(payloadLength >> 8))
        data.append(UInt8(payloadLength & 0xFF))
        
        // Payload
        data.append(payload)
        
        return data
    }
    
    /// Deserialize packet from binary data
    static func fromData(_ data: Data) throws -> BitchatPacket {
        guard data.count >= 4 else {
            throw PacketError.invalidSize
        }
        
        let type = MessageHandler.MessageType(rawValue: data[0]) ?? .unknown
        let ttl = data[1]
        let payloadLength = UInt16(data[2]) << 8 | UInt16(data[3])
        
        guard data.count >= 4 + Int(payloadLength) else {
            throw PacketError.invalidPayloadSize
        }
        
        let payload = data.subdata(in: 4..<4+Int(payloadLength))
        
        return BitchatPacket(type: type, ttl: ttl, payload: payload)
    }
}

// MARK: - Errors

enum PacketError: Error {
    case invalidSize
    case invalidPayloadSize
    case invalidType
}