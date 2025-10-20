//
// RequestSyncPacket.swift
// bitpoints.me
//
// Sync request packet for gossip protocol
//

import Foundation

/// RequestSyncPacket - Request for message synchronization
struct RequestSyncPacket {
    let requesterID: PeerID
    let lastSeenTimestamp: Date
    let requestedMessageTypes: [MessageHandler.MessageType]
    
    init(requesterID: PeerID, lastSeenTimestamp: Date, requestedMessageTypes: [MessageHandler.MessageType] = []) {
        self.requesterID = requesterID
        self.lastSeenTimestamp = lastSeenTimestamp
        self.requestedMessageTypes = requestedMessageTypes
    }
}

// MARK: - Serialization

extension RequestSyncPacket {
    /// Serialize to binary data
    func toData() throws -> Data {
        var data = Data()
        
        // Requester ID (8 bytes)
        let requesterIDData = requesterID.id.prefix(8).data(using: .utf8) ?? Data(count: 8)
        data.append(requesterIDData)
        if requesterIDData.count < 8 {
            data.append(Data(count: 8 - requesterIDData.count))
        }
        
        // Last seen timestamp (8 bytes, big endian)
        let timestampBytes = UInt64(lastSeenTimestamp.timeIntervalSince1970).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: timestampBytes) { Data($0) })
        
        // Requested message types count (1 byte)
        data.append(UInt8(requestedMessageTypes.count))
        
        // Requested message types
        for messageType in requestedMessageTypes {
            data.append(messageType.rawValue)
        }
        
        return data
    }
    
    /// Deserialize from binary data
    static func fromData(_ data: Data) throws -> RequestSyncPacket {
        var offset = 0
        
        // Requester ID (8 bytes)
        guard data.count >= offset + 8 else { throw SyncError.invalidSize }
        let requesterIDData = data.subdata(in: offset..<offset+8)
        let requesterIDString = String(data: requesterIDData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? ""
        let requesterID = PeerID(id: requesterIDString)
        offset += 8
        
        // Last seen timestamp (8 bytes)
        guard data.count >= offset + 8 else { throw SyncError.invalidSize }
        let timestampBytes = data.subdata(in: offset..<offset+8)
        let timestampValue = timestampBytes.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let lastSeenTimestamp = Date(timeIntervalSince1970: TimeInterval(timestampValue))
        offset += 8
        
        // Requested message types count
        guard data.count >= offset + 1 else { throw SyncError.invalidSize }
        let messageTypesCount = Int(data[offset])
        offset += 1
        
        // Requested message types
        var requestedMessageTypes: [MessageHandler.MessageType] = []
        for _ in 0..<messageTypesCount {
            guard data.count >= offset + 1 else { throw SyncError.invalidSize }
            let messageType = MessageHandler.MessageType(rawValue: data[offset]) ?? .unknown
            requestedMessageTypes.append(messageType)
            offset += 1
        }
        
        return RequestSyncPacket(
            requesterID: requesterID,
            lastSeenTimestamp: lastSeenTimestamp,
            requestedMessageTypes: requestedMessageTypes
        )
    }
}

// MARK: - Errors

enum SyncError: Error {
    case invalidSize
    case invalidData
}
