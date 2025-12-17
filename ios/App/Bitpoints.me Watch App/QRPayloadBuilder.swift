import Foundation

public struct QRPayloadBuilder {
    public enum Mode {
        case bitchatPrivateMessage(messageID: String, content: String, recipient: String?)
        case nprofile(pubkey: String, relays: [String])
    }

    public struct Result {
        public let payload: String
        public let pubkeyHex: String
        public let createdAt: Date
    }

    public init() {}

    public func buildPayload(
        mode: Mode,
        senderPeerIdHex: String
    ) -> Result? {
        switch mode {
        case .bitchatPrivateMessage(let messageID, let content, let recipient):
            guard let tlv = BitChatPacketBuilder.encodePrivateMessageTLV(messageID: messageID, content: content) else {
                return nil
            }
            let payload = Data([0x01]) + tlv // payloadType=0x01 followed by TLV body
            guard let encoded = BitChatPacketBuilder.buildBitChatPacket(payload: payload, senderPeerIdHex: senderPeerIdHex, recipientPeerIdHex: recipient) else {
                return nil
            }
            return Result(payload: encoded, pubkeyHex: senderPeerIdHex, createdAt: Date())
        case .nprofile(let pubkey, let relays):
            // Minimal JSON envelope to keep compatibility without full nip19 implementation
            let body: [String: Any] = [
                "type": "nprofile",
                "pubkey": pubkey,
                "relays": relays
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: body, options: []),
                  let json = String(data: data, encoding: .utf8) else {
                return nil
            }
            return Result(payload: json, pubkeyHex: pubkey, createdAt: Date())
        }
    }
}

