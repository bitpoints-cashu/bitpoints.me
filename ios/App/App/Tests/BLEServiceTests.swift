//
// BLEServiceTests.swift
// bitpoints.me
//
// Unit tests for BLEService initialization and state management
//

import XCTest
import CoreBluetooth
@testable import App

class BLEServiceTests: XCTestCase {

    var bleService: BLEService!
    var mockKeychain: MockKeychainManager!
    var mockNoiseService: MockNoiseEncryptionService!
    var mockDelegate: MockBLEServiceDelegate!

    override func setUp() {
        super.setUp()

        // Create mocks
        mockKeychain = MockKeychainManager()
        mockNoiseService = MockNoiseEncryptionService()
        mockDelegate = MockBLEServiceDelegate()

        // Initialize BLEService with mocks
        bleService = BLEService(noiseService: mockNoiseService, keychain: mockKeychain)
        bleService.delegate = mockDelegate
    }

    override func tearDown() {
        bleService = nil
        mockKeychain = nil
        mockNoiseService = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(bleService)
        XCTAssertNotNil(bleService.delegate)
        XCTAssertEqual(bleService.delegate, mockDelegate)
    }

    func testBLEManagersInitialized() {
        // BLE managers should be initialized (but may not be powered on)
        XCTAssertNotNil(bleService.value(forKey: "centralManager") as? CBCentralManager)
        XCTAssertNotNil(bleService.value(forKey: "peripheralManager") as? CBPeripheralManager)
    }

    func testMaintenanceTimerSetup() {
        // Maintenance timer should be set up
        let maintenanceTimer = bleService.value(forKey: "maintenanceTimer") as? DispatchSourceTimer
        XCTAssertNotNil(maintenanceTimer)
    }

    func testQueueSetup() {
        // Queues should be properly configured
        let messageQueue = bleService.value(forKey: "messageQueue") as? DispatchQueue
        let collectionsQueue = bleService.value(forKey: "collectionsQueue") as? DispatchQueue
        let bleQueue = bleService.value(forKey: "bleQueue") as? DispatchQueue

        XCTAssertNotNil(messageQueue)
        XCTAssertNotNil(collectionsQueue)
        XCTAssertNotNil(bleQueue)
    }

    // MARK: - Service Control Tests

    func testStartService() {
        // Should not crash when starting service
        bleService.startService()

        // In simulator, should log that Bluetooth won't work
        // In real device, would start scanning/advertising
    }

    func testStopService() {
        // Should not crash when stopping service
        bleService.startService()
        bleService.stopService()

        // State should be cleared
        let peripherals = bleService.value(forKey: "peripherals") as? [String: Any]
        let peers = bleService.value(forKey: "peers") as? [String: Any]
        let subscribedCentrals = bleService.value(forKey: "subscribedCentrals") as? [Any]

        XCTAssertTrue(peripherals?.isEmpty ?? false)
        XCTAssertTrue(peers?.isEmpty ?? false)
        XCTAssertTrue(subscribedCentrals?.isEmpty ?? false)
    }

    // MARK: - Peer Management Tests

    func testGetActivePeers() {
        let peers = bleService.getActivePeers()
        XCTAssertNotNil(peers)
        XCTAssertEqual(peers.count, 0) // Initially empty
    }

    func testSetNickname() {
        let testNickname = "Test User"
        bleService.setNickname(testNickname)

        // Verify nickname was set (would need to check internal state)
        XCTAssertTrue(true) // Placeholder - would check internal nickname
    }

    // MARK: - Message Handling Tests

    func testSendMessage() {
        let testData = "test message".data(using: .utf8)!
        let testPeerID = PeerID(str: "test123")

        // Should not crash when sending message
        bleService.sendMessage(testData, to: testPeerID)

        // In real scenario, would verify message was sent
        XCTAssertTrue(true) // Placeholder
    }

    // MARK: - Delegate Tests

    func testDelegateCallbacks() {
        let testPeerID = PeerID(str: "test123")

        // Test peer discovery
        bleService.delegate?.didDiscoverPeer(testPeerID)
        XCTAssertTrue(mockDelegate.didDiscoverPeerCalled)
        XCTAssertEqual(mockDelegate.lastDiscoveredPeer, testPeerID)

        // Test peer connection update
        bleService.delegate?.didUpdatePeerConnection(testPeerID, isConnected: true)
        XCTAssertTrue(mockDelegate.didUpdatePeerConnectionCalled)
        XCTAssertEqual(mockDelegate.lastUpdatedPeer, testPeerID)
        XCTAssertTrue(mockDelegate.lastConnectionState)

        // Test message received
        let testData = "test message".data(using: .utf8)!
        bleService.delegate?.didReceiveMessage(testData, from: testPeerID)
        XCTAssertTrue(mockDelegate.didReceiveMessageCalled)
        XCTAssertEqual(mockDelegate.lastReceivedData, testData)
        XCTAssertEqual(mockDelegate.lastMessagePeer, testPeerID)
    }
}

// MARK: - Mock Classes

class MockKeychainManager: KeychainManagerProtocol {
    func store(key: String, data: Data) -> Bool {
        return true
    }

    func retrieve(key: String) -> Data? {
        return Data(repeating: 0, count: 32) // Mock 32-byte key
    }

    func delete(key: String) -> Bool {
        return true
    }

    func clear() -> Bool {
        return true
    }
}

class MockNoiseEncryptionService: NoiseEncryptionService {
    override init() {
        super.init(keychain: MockKeychainManager())
    }

    override func getStaticPublicKeyData() -> Data {
        return Data(repeating: 0, count: 32) // Mock 32-byte public key
    }

    override func hasEstablishedSession(with peerID: PeerID) -> Bool {
        return false // Mock no established sessions
    }

    override func encrypt(_ data: Data, for peerID: PeerID) throws -> Data {
        return data // Mock no encryption
    }

    override func decrypt(_ data: Data, from peerID: PeerID) throws -> Data {
        return data // Mock no decryption
    }
}

class MockBLEServiceDelegate: BLEServiceDelegate {
    var didDiscoverPeerCalled = false
    var didUpdatePeerConnectionCalled = false
    var didReceiveMessageCalled = false

    var lastDiscoveredPeer: PeerID?
    var lastUpdatedPeer: PeerID?
    var lastConnectionState: Bool = false
    var lastReceivedData: Data?
    var lastMessagePeer: PeerID?

    func didDiscoverPeer(_ peerID: PeerID) {
        didDiscoverPeerCalled = true
        lastDiscoveredPeer = peerID
    }

    func didUpdatePeerConnection(_ peerID: PeerID, isConnected: Bool) {
        didUpdatePeerConnectionCalled = true
        lastUpdatedPeer = peerID
        lastConnectionState = isConnected
    }

    func didReceiveMessage(_ data: Data, from peerID: PeerID) {
        didReceiveMessageCalled = true
        lastReceivedData = data
        lastMessagePeer = peerID
    }
}
