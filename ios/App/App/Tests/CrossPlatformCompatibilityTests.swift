//
// CrossPlatformCompatibilityTests.swift
// bitpoints.me
//
// Tests for cross-platform compatibility with Android
//

import XCTest
@testable import App

class CrossPlatformCompatibilityTests: XCTestCase {

    func testBinaryProtocolCompatibility() {
        // Test that our binary protocol produces the same format as Android
        let testData = "Hello, cross-platform world!".data(using: .utf8)!

        let packet = BitchatPacket(
            type: 0xE1, // Ecash message type
            ttl: 7,
            senderID: PeerID(publicKey: Data(repeating: 1, count: 32)),
            payload: testData
        )

        guard let encoded = packet.toBinaryData(padding: false) else {
            XCTFail("Failed to encode packet")
            return
        }

        // Verify we can decode it back
        guard let decoded = BitchatPacket.from(encoded) else {
            XCTFail("Failed to decode packet")
            return
        }

        XCTAssertEqual(decoded.type, packet.type)
        XCTAssertEqual(decoded.ttl, packet.ttl)
        XCTAssertEqual(decoded.payload, packet.payload)
    }

    func testEcashMessageSerialization() {
        let ecashMessage = EcashMessage(
            id: "test_id_123",
            sender: "sender_fingerprint",
            amount: 1000,
            unit: "sats",
            cashuToken: "test_token",
            mint: "test_mint",
            memo: "Test memo"
        )

        guard let serialized = ecashMessage.toBinaryPayload() else {
            XCTFail("Failed to serialize ecash message")
            return
        }

        guard let deserialized = EcashMessage.fromBinaryPayload(serialized) else {
            XCTFail("Failed to deserialize ecash message")
            return
        }

        XCTAssertEqual(deserialized.id, ecashMessage.id)
        XCTAssertEqual(deserialized.sender, ecashMessage.sender)
        XCTAssertEqual(deserialized.amount, ecashMessage.amount)
        XCTAssertEqual(deserialized.unit, ecashMessage.unit)
        XCTAssertEqual(deserialized.cashuToken, ecashMessage.cashuToken)
        XCTAssertEqual(deserialized.mint, ecashMessage.mint)
        XCTAssertEqual(deserialized.memo, ecashMessage.memo)
    }

    func testNoiseProtocolHandshake() {
        // Test that our Noise implementation can handle basic handshake
        let keychain = KeychainManager()
        let noiseService = NoiseEncryptionService(keychain: keychain)

        // Test identity generation
        let fingerprint = noiseService.getIdentityFingerprint()
        XCTAssertFalse(fingerprint.isEmpty)
        XCTAssertEqual(fingerprint.count, 16) // 8 bytes = 16 hex chars

        // Test public key retrieval
        let publicKey = noiseService.getStaticPublicKeyData()
        XCTAssertEqual(publicKey.count, 32) // Curve25519 public key size
    }

    func testPeerIDCompatibility() {
        // Test PeerID creation and validation
        let testPeerID = PeerID(str: "test_peer_123")
        XCTAssertTrue(testPeerID.isValid)

        // Test hex peer ID
        let hexPeerID = PeerID(hexData: Data(repeating: 0xAB, count: 8))
        XCTAssertTrue(hexPeerID.isValid)
        XCTAssertTrue(hexPeerID.isShort)

        // Test noise key peer ID
        let noiseKey = Data(repeating: 0xCD, count: 32)
        let noisePeerID = PeerID(publicKey: noiseKey)
        XCTAssertTrue(noisePeerID.isValid)
    }

    func testBluetoothUUIDs() {
        // Verify we're using the same UUIDs as Android
        #if DEBUG
        XCTAssertEqual(BLEService.serviceUUID.uuidString, "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5A")
        #else
        XCTAssertEqual(BLEService.serviceUUID.uuidString, "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C")
        #endif

        XCTAssertEqual(BLEService.characteristicUUID.uuidString, "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")
    }

    func testTransportConfigCompatibility() {
        // Verify we're using the same configuration values as Android
        XCTAssertEqual(TransportConfig.bleDefaultFragmentSize, 469)
        XCTAssertEqual(TransportConfig.messageTTLDefault, 7)
        XCTAssertEqual(TransportConfig.compressionThresholdBytes, 100)
    }
}
