//
// IdentityAnnouncement.swift
// bitpoints.me
//
// Identity announcement message for peer discovery
//

import Foundation

/// IdentityAnnouncement - Peer identity announcement message
struct IdentityAnnouncement {
    let peerID: PeerID
    let nickname: String
    let noisePublicKey: Data
    let signingPublicKey: Data
    let timestamp: Date
    
    init(peerID: PeerID, nickname: String, noisePublicKey: Data, signingPublicKey: Data) {
        self.peerID = peerID
        self.nickname = nickname
        self.noisePublicKey = noisePublicKey
        self.signingPublicKey = signingPublicKey
        self.timestamp = Date()
    }
}

// MARK: - Serialization

extension IdentityAnnouncement {
    /// Serialize to binary data
    func toData() throws -> Data {
        var data = Data()
        
        // Peer ID (8 bytes)
        let peerIDData = peerID.id.prefix(8).data(using: .utf8) ?? Data(count: 8)
        data.append(peerIDData)
        if peerIDData.count < 8 {
            data.append(Data(count: 8 - peerIDData.count))
        }
        
        // Nickname length (1 byte)
        let nicknameData = nickname.data(using: .utf8) ?? Data()
        data.append(UInt8(nicknameData.count))
        
        // Nickname
        data.append(nicknameData)
        
        // Noise public key length (1 byte)
        data.append(UInt8(noisePublicKey.count))
        
        // Noise public key
        data.append(noisePublicKey)
        
        // Signing public key length (1 byte)
        data.append(UInt8(signingPublicKey.count))
        
        // Signing public key
        data.append(signingPublicKey)
        
        // Timestamp (8 bytes, big endian)
        let timestampBytes = UInt64(timestamp.timeIntervalSince1970).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: timestampBytes) { Data($0) })
        
        return data
    }
    
    /// Deserialize from binary data
    static func fromData(_ data: Data) throws -> IdentityAnnouncement {
        var offset = 0
        
        // Peer ID (8 bytes)
        guard data.count >= offset + 8 else { throw AnnouncementError.invalidSize }
        let peerIDData = data.subdata(in: offset..<offset+8)
        let peerIDString = String(data: peerIDData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? ""
        let peerID = PeerID(id: peerIDString)
        offset += 8
        
        // Nickname length
        guard data.count >= offset + 1 else { throw AnnouncementError.invalidSize }
        let nicknameLength = Int(data[offset])
        offset += 1
        
        // Nickname
        guard data.count >= offset + nicknameLength else { throw AnnouncementError.invalidSize }
        let nicknameData = data.subdata(in: offset..<offset+nicknameLength)
        let nickname = String(data: nicknameData, encoding: .utf8) ?? ""
        offset += nicknameLength
        
        // Noise public key length
        guard data.count >= offset + 1 else { throw AnnouncementError.invalidSize }
        let noiseKeyLength = Int(data[offset])
        offset += 1
        
        // Noise public key
        guard data.count >= offset + noiseKeyLength else { throw AnnouncementError.invalidSize }
        let noisePublicKey = data.subdata(in: offset..<offset+noiseKeyLength)
        offset += noiseKeyLength
        
        // Signing public key length
        guard data.count >= offset + 1 else { throw AnnouncementError.invalidSize }
        let signingKeyLength = Int(data[offset])
        offset += 1
        
        // Signing public key
        guard data.count >= offset + signingKeyLength else { throw AnnouncementError.invalidSize }
        let signingPublicKey = data.subdata(in: offset..<offset+signingKeyLength)
        offset += signingKeyLength
        
        // Timestamp
        guard data.count >= offset + 8 else { throw AnnouncementError.invalidSize }
        let timestampBytes = data.subdata(in: offset..<offset+8)
        let timestampValue = timestampBytes.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampValue))
        
        return IdentityAnnouncement(
            peerID: peerID,
            nickname: nickname,
            noisePublicKey: noisePublicKey,
            signingPublicKey: signingPublicKey
        )
    }
}

// MARK: - Errors

enum AnnouncementError: Error {
    case invalidSize
    case invalidData
}
