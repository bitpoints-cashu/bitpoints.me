import Foundation

public struct BitChatPacketBuilder {
    public static let defaultTTL: UInt8 = 7
    public static let version: UInt8 = 1
    public static let messageTypeNoiseEncrypted: UInt8 = 0x11
    public static let flagHasRecipient: UInt8 = 0x01

    public static func normalizePeerId(_ peerId: String) -> String {
        let hex = peerId.lowercased().replacingOccurrences(of: "[^0-9a-f]", with: "", options: .regularExpression)
        if hex.count >= 16 {
            let start = hex.startIndex
            let end = hex.index(start, offsetBy: 16)
            return String(hex[start..<end])
        }
        return hex.padding(toLength: 16, withPad: "0", startingAt: 0)
    }

    public static func encodePrivateMessageTLV(messageID: String, content: String) -> Data? {
        guard
            let msgBytes = messageID.data(using: .utf8),
            let contentBytes = content.data(using: .utf8),
            msgBytes.count <= 255,
            contentBytes.count <= 255
        else { return nil }

        var buffer = Data()
        buffer.append(0x00)
        buffer.append(UInt8(msgBytes.count))
        buffer.append(msgBytes)
        buffer.append(0x01)
        buffer.append(UInt8(contentBytes.count))
        buffer.append(contentBytes)
        return buffer
    }

    public static func buildBitChatPacket(
        payload: Data,
        senderPeerIdHex: String,
        recipientPeerIdHex: String?
    ) -> String? {
        do {
            let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
            let hasRecipient = recipientPeerIdHex != nil

            let senderBytes = Data(hex: normalizePeerId(senderPeerIdHex)).prefix(8)
            let recipientBytes = hasRecipient ? Data(hex: normalizePeerId(recipientPeerIdHex!)).prefix(8) : Data()
            let payloadLength = UInt16(payload.count)

            var buffer = Data()
            buffer.append(version)
            buffer.append(messageTypeNoiseEncrypted)
            buffer.append(defaultTTL)
            buffer.appendBigEndian(timestamp)
            buffer.append(hasRecipient ? flagHasRecipient : 0x00)
            buffer.appendBigEndian(payloadLength)
            buffer.append(senderBytes)
            if hasRecipient {
                buffer.append(recipientBytes)
            }
            buffer.append(payload)

            return "bitchat1:" + Base64URL.encode(buffer)
        } catch {
            return nil
        }
    }
}

private extension Data {
    init(hex: String) {
        self.init()
        var hexStr = hex
        if hexStr.count % 2 != 0 { hexStr = "0" + hexStr }
        var index = hexStr.startIndex
        while index < hexStr.endIndex {
            let next = hexStr.index(index, offsetBy: 2)
            let byteString = hexStr[index..<next]
            let num = UInt8(byteString, radix: 16) ?? 0
            append(num)
            index = next
        }
    }

    mutating func appendBigEndian(_ value: UInt16) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }

    mutating func appendBigEndian(_ value: UInt64) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
}

