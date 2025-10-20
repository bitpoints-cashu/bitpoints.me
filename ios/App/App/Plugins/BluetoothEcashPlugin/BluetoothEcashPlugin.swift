import Foundation
import Capacitor

/**
 * BluetoothEcashPlugin
 *
 * Capacitor plugin to expose Bluetooth ecash functionality to JavaScript
 * This bridges the BluetoothEcashService (Swift) to the Vue/Quasar frontend (TypeScript)
 */
@objc(BluetoothEcashPlugin)
public class BluetoothEcashPlugin: CAPPlugin, CAPBridgedPlugin {

    private var bluetoothService: BluetoothEcashService?

    public static let identifier = "BluetoothEcash"
    public static let jsName = "BluetoothEcash"

    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "startService", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopService", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sendToken", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getActivePeers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAvailablePeers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getUnclaimedTokens", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "markTokenClaimed", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setNickname", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getNickname", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isBluetoothEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestBluetoothEnable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sendTextMessage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openAppSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startAlwaysOnMode", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopAlwaysOnMode", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isAlwaysOnActive", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestBatteryOptimizationExemption", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        super.load()
        print("🔵 BluetoothEcashPlugin loaded")

        // Initialize service
        bluetoothService = BluetoothEcashService()
        bluetoothService?.delegate = self
        print("🔵 BluetoothEcashPlugin service initialized")

        // Match bitchat behavior: proactively request permissions and start BLE on first launch
        bluetoothService?.requestPermissions { [weak self] result in
            switch result {
            case .success:
                self?.bluetoothService?.startService { startResult in
                    if case .failure(let err) = startResult {
                        print("🔵 BluetoothEcashPlugin auto-start failed: \(err.localizedDescription)")
                    }
                }
            case .failure(let err):
                print("🔵 BluetoothEcashPlugin permission probe failed: \(err.localizedDescription)")
            }
        }
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
        print("🔵 BluetoothEcashPlugin sendToken called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        // Get parameters from call options (matching JavaScript interface)
        guard let options = call.getObject("options") else {
            print("🔵 BluetoothEcashPlugin ERROR: Missing options parameter")
            call.reject("Missing required parameter: options")
            return
        }

        guard let token = options["token"] as? String,
              let amount = options["amount"] as? Int,
              let unit = options["unit"] as? String,
              let senderNpub = options["senderNpub"] as? String else {
            print("🔵 BluetoothEcashPlugin ERROR: Missing required parameters in options")
            call.reject("Missing required parameters: token, amount, unit, senderNpub")
            return
        }

        let peerID = options["peerID"] as? String
        let memo = options["memo"] as? String
        let mint = options["mint"] as? String ?? ""

        print("🔵 BluetoothEcashPlugin sending token: amount=\(amount), unit=\(unit), peerID=\(peerID ?? "broadcast")")

        bluetoothService.sendToken(options) { [weak self] result in
            switch result {
            case .success(let messageId):
                print("🔵 BluetoothEcashPlugin token sent successfully: \(messageId)")
                call.resolve(["messageId": messageId])
            case .failure(let error):
                print("🔵 BluetoothEcashPlugin ERROR: Failed to send token: \(error.localizedDescription)")
                call.reject("Failed to send token: \(error.localizedDescription)")
            }
        }
    }

    @objc func getActivePeers(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin getActivePeers called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        let peers = bluetoothService.getActivePeers()
        print("🔵 BluetoothEcashPlugin returning \(peers.count) active peers")
        call.resolve(["peers": peers])
    }

    // JS expects getAvailablePeers(); map to getActivePeers()
    @objc func getAvailablePeers(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin getAvailablePeers called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }
        let peers = bluetoothService.getAvailablePeers()
        print("🔵 BluetoothEcashPlugin returning \(peers.count) available peers")
        call.resolve(["peers": peers])
    }

    @objc func getUnclaimedTokens(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin getUnclaimedTokens called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        let tokens = bluetoothService.getUnclaimedTokens()
        print("🔵 BluetoothEcashPlugin returning \(tokens.count) unclaimed tokens")
        call.resolve(["tokens": tokens])
    }

    @objc func markTokenClaimed(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin markTokenClaimed called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        guard let messageId = call.getString("messageId") else {
            print("🔵 BluetoothEcashPlugin ERROR: Missing messageId parameter")
            call.reject("Message ID is required")
            return
        }

        bluetoothService.markTokenClaimed(messageId: messageId) { [weak self] result in
            switch result {
            case .success:
                print("🔵 BluetoothEcashPlugin token marked as claimed: \(messageId)")
                call.resolve()
            case .failure(let error):
                print("🔵 BluetoothEcashPlugin ERROR: Failed to mark token claimed: \(error.localizedDescription)")
                call.reject("Failed to mark token claimed: \(error.localizedDescription)")
            }
        }
    }

    @objc func setNickname(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin setNickname called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        guard let nickname = call.getString("nickname") else {
            print("🔵 BluetoothEcashPlugin ERROR: Missing nickname parameter")
            call.reject("Nickname is required")
            return
        }

        bluetoothService.setNickname(nickname) { [weak self] result in
            switch result {
            case .success(let newNickname):
                print("🔵 BluetoothEcashPlugin nickname set to: \(newNickname)")
                call.resolve(["nickname": newNickname])
            case .failure(let error):
                print("🔵 BluetoothEcashPlugin ERROR: Failed to set nickname: \(error.localizedDescription)")
                call.reject("Failed to set nickname: \(error.localizedDescription)")
            }
        }
    }

    @objc func getNickname(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin getNickname called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        let nickname = bluetoothService.getNickname()
        print("🔵 BluetoothEcashPlugin returning nickname: \(nickname)")
        call.resolve(["nickname": nickname])
    }

    // Optional helper used by UI; currently a no-op on native
    @objc func sendTextMessage(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin sendTextMessage called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        guard let peerID = call.getString("peerID"),
              let message = call.getString("message") else {
            print("🔵 BluetoothEcashPlugin ERROR: Missing peerID or message parameter")
            call.reject("peerID and message are required")
            return
        }

        bluetoothService.sendTextMessage(message: message, toPeer: peerID) { [weak self] result in
            switch result {
            case .success:
                print("🔵 BluetoothEcashPlugin text message sent to \(peerID)")
                call.resolve()
            case .failure(let error):
                print("🔵 BluetoothEcashPlugin ERROR: Failed to send text message: \(error.localizedDescription)")
                call.reject("Failed to send text message: \(error.localizedDescription)")
            }
        }
    }

    // Always-on mode methods (iOS doesn't support background BLE like Android)
    @objc func startAlwaysOnMode(_ call: CAPPluginCall) {
        // iOS doesn't support always-on BLE background mode like Android
        // Return success to avoid UNIMPLEMENTED errors
        call.resolve(["success": true, "message": "Always-on mode not supported on iOS"])
    }

    @objc func stopAlwaysOnMode(_ call: CAPPluginCall) {
        // iOS doesn't support always-on BLE background mode like Android
        call.resolve(["success": true, "message": "Always-on mode not supported on iOS"])
    }

    @objc func isAlwaysOnActive(_ call: CAPPluginCall) {
        // iOS doesn't support always-on BLE background mode like Android
        call.resolve(["isActive": false, "message": "Always-on mode not supported on iOS"])
    }

    @objc func requestBatteryOptimizationExemption(_ call: CAPPluginCall) {
        // iOS doesn't have battery optimization like Android
        call.resolve(["success": true, "message": "Battery optimization not applicable on iOS"])
    }

    @objc func isBluetoothEnabled(_ call: CAPPluginCall) {
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        let isEnabled = bluetoothService.isBluetoothEnabled()
        print("🔵 BluetoothEcashPlugin isBluetoothEnabled: \(isEnabled)")
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

    // MARK: - Settings helpers

    @objc func openAppSettings(_ call: CAPPluginCall) {
        #if os(iOS)
        DispatchQueue.main.async {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:]) { _ in
                    call.resolve()
                }
            } else {
                call.reject("Failed to build settings URL")
            }
        }
        #else
        call.reject("Not supported on this platform")
        #endif
    }

    @objc func requestPermissions(_ call: CAPPluginCall) {
        print("🔵 BluetoothEcashPlugin requestPermissions called")
        guard let bluetoothService = bluetoothService else {
            print("🔵 BluetoothEcashPlugin ERROR: Bluetooth service not initialized")
            call.reject("Bluetooth service not initialized")
            return
        }

        print("🔵 BluetoothEcashPlugin requesting permissions...")
        bluetoothService.requestPermissions { [weak self] result in
            switch result {
            case .success:
                print("🔵 BluetoothEcashPlugin permissions granted")
                call.resolve(["granted": true])
            case .failure(let error):
                print("🔵 BluetoothEcashPlugin ERROR: Permission denied: \(error.localizedDescription)")
                call.reject("Permission denied: \(error.localizedDescription)")
            }
        }
    }

}

// MARK: - BluetoothEcashServiceDelegate
extension BluetoothEcashPlugin: BluetoothEcashServiceDelegate {
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didUpdateState state: CBManagerState) {
        print("🔵 BluetoothEcashPlugin: BLE state updated: \(state.debugDescription)")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didUpdatePeripheralState state: CBManagerState) {
        print("🔵 BluetoothEcashPlugin: BLE peripheral state updated: \(state.debugDescription)")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didConnectPeripheral peripheral: CBPeripheral) {
        print("🔵 BluetoothEcashPlugin: Connected to peripheral: \(peripheral.identifier)")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didFailToConnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔵 BluetoothEcashPlugin: Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "unknown")")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔵 BluetoothEcashPlugin: Disconnected from peripheral: \(peripheral.identifier)")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didSubscribeToCharacteristic characteristic: CBCharacteristic, central: CBCentral) {
        print("🔵 BluetoothEcashPlugin: Central subscribed to characteristic: \(characteristic.uuid)")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic, central: CBCentral) {
        print("🔵 BluetoothEcashPlugin: Central unsubscribed from characteristic: \(characteristic.uuid)")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveData data: Data, from source: Any) {
        print("🔵 BluetoothEcashPlugin: Received data from source")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveEcashMessage message: [String: Any]) {
        print("🔵 BluetoothEcashPlugin: Received ecash message")
        // Notify JavaScript about received ecash
        notifyListeners("ecashReceived", data: message)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveTextMessage message: [String: Any]) {
        print("🔵 BluetoothEcashPlugin: Received text message")
        // Could notify JavaScript if needed
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didDiscoverPeer peerInfo: [String: Any]) {
        print("🔵 BluetoothEcashPlugin: Discovered peer: \(peerInfo["peerID"] ?? "unknown")")
        // Notify JavaScript about peer discovery
        notifyListeners("peerDiscovered", data: peerInfo)
    }
}
