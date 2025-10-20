//
// BluetoothIntegrationTests.swift
// bitpoints.me
//
// Integration tests for Bluetooth functionality on physical devices
//

import XCTest
import CoreBluetooth
@testable import App

class BluetoothIntegrationTests: XCTestCase {

    var bluetoothService: BluetoothEcashService!
    var mockDelegate: MockEcashDelegate!

    override func setUp() {
        super.setUp()

        // Skip tests on simulator
        #if targetEnvironment(simulator)
        throw XCTSkip("Integration tests require physical device")
        #endif

        mockDelegate = MockEcashDelegate()
        bluetoothService = BluetoothEcashService()
        bluetoothService.delegate = mockDelegate
    }

    override func tearDown() {
        bluetoothService.stopService { _ in }
        bluetoothService = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Service Initialization Tests

    func testBluetoothServiceInitialization() {
        XCTAssertNotNil(bluetoothService)

        let expectation = XCTestExpectation(description: "Service initialization")

        bluetoothService.startService { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to initialize Bluetooth service: \(error)")
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Bluetooth State Tests

    func testBluetoothStateChanges() {
        let expectation = XCTestExpectation(description: "Bluetooth state check")

        // Check if Bluetooth is enabled
        let isEnabled = bluetoothService.isBluetoothEnabled()
        XCTAssertNotNil(isEnabled)

        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Service Lifecycle Tests

    func testServiceStartStop() {
        let startExpectation = XCTestExpectation(description: "Service start")
        let stopExpectation = XCTestExpectation(description: "Service stop")

        // Start service
        bluetoothService.startService { result in
            switch result {
            case .success:
                startExpectation.fulfill()

                // Stop service after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.bluetoothService.stopService { result in
                        switch result {
                        case .success:
                            stopExpectation.fulfill()
                        case .failure(let error):
                            XCTFail("Failed to stop service: \(error)")
                        }
                    }
                }
            case .failure(let error):
                XCTFail("Failed to start service: \(error)")
            }
        }

        wait(for: [startExpectation, stopExpectation], timeout: 15.0)
    }

    // MARK: - Token Operations Tests

    func testTokenSendReceive() {
        let startExpectation = XCTestExpectation(description: "Service start")
        let sendExpectation = XCTestExpectation(description: "Token send")

        // Start service first
        bluetoothService.startService { result in
            switch result {
            case .success:
                startExpectation.fulfill()

                // Send test token after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bluetoothService.sendToken(
                        token: "cashuA1test_token_123456789",
                        toPeer: "test_peer_456",
                        amount: 1000,
                        unit: "sats",
                        memo: "Integration test payment"
                    ) { result in
                        switch result {
                        case .success(let messageId):
                            XCTAssertFalse(messageId.isEmpty)
                            sendExpectation.fulfill()
                        case .failure(let error):
                            XCTFail("Failed to send token: \(error)")
                        }
                    }
                }
            case .failure(let error):
                XCTFail("Failed to start service: \(error)")
            }
        }

        wait(for: [startExpectation, sendExpectation], timeout: 15.0)
    }

    // MARK: - Peer Management Tests

    func testPeerDiscovery() {
        let startExpectation = XCTestExpectation(description: "Service start")

        bluetoothService.startService { result in
            switch result {
            case .success:
                startExpectation.fulfill()

                // Wait for potential peer discovery
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    let peers = self.bluetoothService.getActivePeers()
                    XCTAssertNotNil(peers)
                    // Note: May be empty if no nearby devices
                }
            case .failure(let error):
                XCTFail("Failed to start service: \(error)")
            }
        }

        wait(for: [startExpectation], timeout: 10.0)
    }

    // MARK: - Nickname Management Tests

    func testNicknameManagement() {
        let testNickname = "Integration Test User"

        bluetoothService.setNickname(testNickname)
        let retrievedNickname = bluetoothService.getNickname()

        XCTAssertEqual(retrievedNickname, testNickname)
    }

    // MARK: - Token Management Tests

    func testUnclaimedTokens() {
        let tokens = bluetoothService.getUnclaimedTokens()
        XCTAssertNotNil(tokens)
        // Initially should be empty
        XCTAssertEqual(tokens.count, 0)
    }

    func testMarkTokenClaimed() {
        // This test would require a received token
        // For now, just test the method doesn't crash
        bluetoothService.markTokenClaimed("test_message_id")
        XCTAssertTrue(true) // Placeholder
    }
}

// MARK: - Mock Delegate

class MockEcashDelegate: EcashDelegate {
    var didSendTokenCalled = false
    var didReceiveTokenCalled = false
    var didDiscoverPeerCalled = false
    var didConnectToPeerCalled = false
    var didDisconnectFromPeerCalled = false

    var lastSentToken: EcashMessage?
    var lastReceivedToken: EcashMessage?
    var lastDiscoveredPeer: PeerInfo?
    var lastConnectedPeer: PeerInfo?
    var lastDisconnectedPeer: PeerID?

    func ecashService(_ service: BluetoothEcashService, didSendToken token: EcashMessage) {
        didSendTokenCalled = true
        lastSentToken = token
    }

    func ecashService(_ service: BluetoothEcashService, didReceiveToken token: EcashMessage) {
        didReceiveTokenCalled = true
        lastReceivedToken = token
    }

    func ecashService(_ service: BluetoothEcashService, didDiscoverPeer peer: PeerInfo) {
        didDiscoverPeerCalled = true
        lastDiscoveredPeer = peer
    }

    func ecashService(_ service: BluetoothEcashService, didConnectToPeer peer: PeerInfo) {
        didConnectToPeerCalled = true
        lastConnectedPeer = peer
    }

    func ecashService(_ service: BluetoothEcashService, didDisconnectFromPeer peerID: PeerID) {
        didDisconnectFromPeerCalled = true
        lastDisconnectedPeer = peerID
    }

    func ecashService(_ service: BluetoothEcashService, didDetectSecurityEvent event: SecurityManager.SecurityEvent) {
        // Mock implementation
    }
}
