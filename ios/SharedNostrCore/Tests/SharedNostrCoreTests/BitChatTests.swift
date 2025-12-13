import XCTest
@testable import SharedNostrCore

final class BitChatTests: XCTestCase {
    func testBase64UrlRoundTrip() {
        let message = "hello world"
        let data = message.data(using: .utf8)!
        let encoded = Base64URL.encode(data)
        let decoded = Base64URL.decode(encoded)
        XCTAssertEqual(decoded, data)
    }

    func testBitChatPacketPrefix() {
        let tlv = BitChatPacketBuilder.encodePrivateMessageTLV(messageID: "id1", content: "ping")!
        let payload = Data([0x01]) + tlv
        let packet = BitChatPacketBuilder.buildBitChatPacket(
            payload: payload,
            senderPeerIdHex: "abcdef0123456789",
            recipientPeerIdHex: nil
        )
        XCTAssertNotNil(packet)
        XCTAssertTrue(packet?.hasPrefix("bitchat1:") ?? false)
    }
}

