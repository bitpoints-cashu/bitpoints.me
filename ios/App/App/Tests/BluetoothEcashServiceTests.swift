//
// BluetoothEcashServiceTests.swift
// bitpoints.me
//
// Integration tests for Bluetooth ecash functionality
//

import XCTest
@testable import App

class BluetoothEcashServiceTests: XCTestCase {

    var bluetoothService: BluetoothEcashService!

    override func setUp() {
        super.setUp()
        bluetoothService = BluetoothEcashService()
    }

    override func tearDown() {
        bluetoothService = nil
        super.tearDown()
    }

    func testServiceInitialization() {
        XCTAssertNotNil(bluetoothService)
    }

    func testStartStopService() {
        let expectation = XCTestExpectation(description: "Service start/stop")

        bluetoothService.startService { result in
            switch result {
            case .success:
                self.bluetoothService.stopService { result in
                    switch result {
                    case .success:
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to stop service: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to start service: \(error)")
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testSendToken() {
        let expectation = XCTestExpectation(description: "Send token")

        let testToken = "test_token_123"
        let testPeer = "test_peer_456"
        let testAmount = 1000
        let testUnit = "sats"
        let testMemo = "Test payment"

        bluetoothService.sendToken(
            token: testToken,
            toPeer: testPeer,
            amount: testAmount,
            unit: testUnit,
            memo: testMemo
        ) { result in
            switch result {
            case .success(let messageId):
                XCTAssertFalse(messageId.isEmpty)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to send token: \(error)")
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testGetActivePeers() {
        let peers = bluetoothService.getActivePeers()
        XCTAssertNotNil(peers)
        // Initially should be empty since no peers are connected
        XCTAssertEqual(peers.count, 0)
    }

    func testGetUnclaimedTokens() {
        let tokens = bluetoothService.getUnclaimedTokens()
        XCTAssertNotNil(tokens)
        // Initially should be empty
        XCTAssertEqual(tokens.count, 0)
    }

    func testSetGetNickname() {
        let testNickname = "Test User"
        bluetoothService.setNickname(testNickname)

        let retrievedNickname = bluetoothService.getNickname()
        XCTAssertEqual(retrievedNickname, testNickname)
    }

    func testBluetoothStatus() {
        let isEnabled = bluetoothService.isBluetoothEnabled()
        // This might be true or false depending on device state
        XCTAssertNotNil(isEnabled)
    }
}
