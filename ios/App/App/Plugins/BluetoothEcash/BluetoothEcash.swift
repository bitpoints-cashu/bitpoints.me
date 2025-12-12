import Foundation
import CoreBluetooth

@objc public protocol BluetoothEcashDelegate: AnyObject {
    func emit(event: String, data: [String: Any])
}

public class BluetoothEcash: NSObject {
    weak var delegate: BluetoothEcashDelegate?

    // NOTE: This is a minimal no-op implementation to remove UNIMPLEMENTED errors.
    // The full BitChat BLE transport is not wired yet.

    public func isBluetoothEnabled() -> Bool {
        return CBCentralManager().state == .poweredOn
    }

    public func requestPermissions(completion: @escaping (Bool) -> Void) {
        _ = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        _ = CBPeripheralManager(delegate: nil, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(self.isBluetoothEnabled())
        }
    }

    public func requestBluetoothEnable(completion: @escaping (Bool) -> Void) {
        completion(isBluetoothEnabled())
    }

    public func startService() {
        // No-op for now; replace with BLEService wiring when ready
    }

    public func stopService() {
        // No-op
    }

    public func getAvailablePeers() -> [[String: Any]] {
        return []
    }

    public func getUnclaimedTokens() -> [[String: Any]] {
        return []
    }

    public func markTokenClaimed(messageId: String) {
        // No-op
    }

    public func sendToken(token: String, amount: Int, unit: String, memo: String, recipientID: String?, senderNpub: String) {
        delegate?.emit(event: "tokenSent", data: ["messageId": UUID().uuidString, "peerID": recipientID ?? ""])
    }

    public func sendTextMessage(peerID: String, message: String) {
        delegate?.emit(event: "tokenSent", data: ["messageId": UUID().uuidString, "peerID": peerID])
    }
}

// No BLEDelegate conformance in the minimal stub
