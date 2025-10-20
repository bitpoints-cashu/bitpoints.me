import Foundation
import Capacitor

/**
 * BluetoothEcashPlugin
 *
 * Capacitor plugin to expose Bluetooth ecash functionality to JavaScript
 * This bridges the BluetoothEcashService (Swift) to the Vue/Quasar frontend (TypeScript)
 */
@objc(BluetoothEcashPlugin)
public class BluetoothEcashPlugin: CAPPlugin {

    private var bluetoothService: BluetoothEcashService?

    override public func load() {
        super.load()
        print("🔵 BluetoothEcashPlugin loaded")

        // Initialize service
        bluetoothService = BluetoothEcashService()
        bluetoothService?.delegate = self
        print("🔵 BluetoothEcashPlugin service initialized")
    }

    // MARK: - Plugin Methods

    @objc func startService(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin startService called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        print("🔵 BluetoothEcashPlugin starting Bluetooth service...")
        bluetoothService.startService { [weak self] result in
            switch result {
            case .success:
                print("🔵 BluetoothEcashPlugin service started successfully")
                call.resolve()
            case .failure(let error):
                print("🔵 BluetoothEcashPlugin ERROR: Failed to start service: \(error.localizedDescription)")
                call.reject("Failed to start service: \(error.localizedDescription)")
            }
        }
    }

    @objc func stopService(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        bluetoothService.stopService { [weak self] result in
            switch result {
            case .success:
                call.resolve()
            case .failure(let error):
                call.reject("Failed to stop service: \(error.localizedDescription)")
            }
        }
    }

    @objc func sendToken(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        guard let token = call.getString("token"),
              let peerID = call.getString("peerID"),
              let amount = call.getInt("amount"),
              let unit = call.getString("unit") else {
            call.reject("Missing required parameters: token, peerID, amount, unit")
            return
        }

        let memo = call.getString("memo")

        bluetoothService.sendToken(
            token: token,
            toPeer: peerID,
            amount: amount,
            unit: unit,
            memo: memo
        ) { [weak self] result in
            switch result {
            case .success(let messageId):
                call.resolve(["messageId": messageId])
            case .failure(let error):
                call.reject("Failed to send token: \(error.localizedDescription)")
            }
        }
    }

    @objc func getActivePeers(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        let peers = bluetoothService.getActivePeers()
        let peerDicts = peers.map { peerToDict($0) }
        call.resolve(["peers": peerDicts])
    }

    @objc func getUnclaimedTokens(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        let tokens = bluetoothService.getUnclaimedTokens()
        let tokenDicts = tokens.map { ecashMessageToDict($0) }
        call.resolve(["tokens": tokenDicts])
    }

    @objc func markTokenClaimed(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        guard let messageId = call.getString("messageId") else {
            call.reject("Message ID is required")
            return
        }

        bluetoothService.markTokenClaimed(messageId)
        call.resolve()
    }

    @objc func setNickname(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        guard let nickname = call.getString("nickname") else {
            call.reject("Nickname is required")
            return
        }

        bluetoothService.setNickname(nickname)
        call.resolve()
    }

    @objc func getNickname(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        let nickname = bluetoothService.getNickname()
        call.resolve(["nickname": nickname])
    }

    @objc func isBluetoothEnabled(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        let isEnabled = bluetoothService.isBluetoothEnabled()
        call.resolve(["enabled": isEnabled])
    }

    @objc func requestBluetoothEnable(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        bluetoothService.requestBluetoothEnable { [weak self] result in
            switch result {
            case .success:
                call.resolve(["enabled": true])
            case .failure(let error):
                call.reject("Failed to enable Bluetooth: \(error.localizedDescription)")
            }
        }
    }

    @objc func requestPermissions(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            call.reject("Bluetooth service not initialized")
            return
        }

        bluetoothService.requestPermissions { [weak self] result in
            switch result {
            case .success:
                call.resolve(["granted": true])
            case .failure(let error):
                call.reject("Permission denied: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper Methods

    private func peerToDict(_ peer: PeerInfo) -> [String: Any] {
        return [
            "peerID": peer.id,
            "nickname": peer.nickname,
            "lastSeen": peer.lastSeen.timeIntervalSince1970 * 1000, // Convert to milliseconds
            "isDirect": peer.isDirectConnection,
            "nostrNpub": peer.nostrNpub ?? "",
            "isConnected": peer.isConnected
        ]
    }

    private func ecashMessageToDict(_ message: EcashMessage) -> [String: Any] {
        return [
            "id": message.id,
            "sender": message.sender,
            "amount": message.amount,
            "unit": message.unit,
            "cashuToken": message.cashuToken,
            "mint": message.mint,
            "memo": message.memo ?? "",
            "timestamp": message.timestamp.timeIntervalSince1970 * 1000, // Convert to milliseconds
            "claimed": message.claimed
        ]
    }
}

// MARK: - EcashDelegate

extension BluetoothEcashPlugin: EcashDelegate {

    func onEcashReceived(message: EcashMessage) {
        print("📬 Notifying frontend of received token")
        notifyListeners("ecashReceived", data: ecashMessageToDict(message))
    }

    func onPeerDiscovered(peer: PeerInfo) {
        print("👥 Notifying frontend of discovered peer: \(peer.id)")
        notifyListeners("peerDiscovered", data: peerToDict(peer))
    }

    func onPeerLost(peerID: String) {
        print("👋 Notifying frontend of lost peer: \(peerID)")
        notifyListeners("peerLost", data: ["peerID": peerID])
    }

    func onTokenSent(messageId: String) {
        print("✅ Notifying frontend of sent token: \(messageId)")
        notifyListeners("tokenSent", data: ["messageId": messageId])
    }

    func onTokenDelivered(messageId: String, peerID: String) {
        print("📨 Notifying frontend of delivered token: \(messageId) to \(peerID)")
        notifyListeners("tokenDelivered", data: ["messageId": messageId, "peerID": peerID])
    }

    func onTokenSendFailed(messageId: String, reason: String) {
        print("❌ Notifying frontend of failed token: \(messageId) - \(reason)")
        notifyListeners("tokenSendFailed", data: ["messageId": messageId, "reason": reason])
    }
}
