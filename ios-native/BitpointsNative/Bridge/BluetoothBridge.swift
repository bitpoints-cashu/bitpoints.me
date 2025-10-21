import Foundation
import os.log

class BluetoothBridge: NSObject {
    private let logger = Logger(subsystem: "me.bitpoints.native", category: "BluetoothBridge")
    
    weak var bluetoothService: BluetoothEcashService?
    weak var webViewBridge: WebViewBridge?
    
    init(bluetoothService: BluetoothEcashService, webViewBridge: WebViewBridge) {
        self.bluetoothService = bluetoothService
        self.webViewBridge = webViewBridge
        super.init()
        
        // Set up delegate to receive events from Bluetooth service
        bluetoothService.delegate = self
    }
}

// MARK: - BluetoothEcashServiceDelegate

extension BluetoothBridge: BluetoothEcashServiceDelegate {
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didUpdateState state: CBManagerState) {
        logger.info("🔵 Bluetooth state updated: \(state.debugDescription)")
        
        let stateData: [String: Any] = [
            "state": state.rawValue,
            "description": state.debugDescription
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_stateChanged", data: stateData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didUpdatePeripheralState state: CBManagerState) {
        logger.info("🔵 Bluetooth peripheral state updated: \(state.debugDescription)")
        
        let stateData: [String: Any] = [
            "state": state.rawValue,
            "description": state.debugDescription
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_peripheralStateChanged", data: stateData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didConnectPeripheral peripheral: CBPeripheral) {
        logger.info("🔵 Connected to peripheral: \(peripheral.identifier)")
        
        let peripheralData: [String: Any] = [
            "identifier": peripheral.identifier.uuidString,
            "name": peripheral.name ?? "Unknown"
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_peripheralConnected", data: peripheralData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didFailToConnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.error("🔵 Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "unknown")")
        
        let errorData: [String: Any] = [
            "identifier": peripheral.identifier.uuidString,
            "name": peripheral.name ?? "Unknown",
            "error": error?.localizedDescription ?? "Unknown error"
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_peripheralConnectionFailed", data: errorData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("🔵 Disconnected from peripheral: \(peripheral.identifier)")
        
        let peripheralData: [String: Any] = [
            "identifier": peripheral.identifier.uuidString,
            "name": peripheral.name ?? "Unknown",
            "error": error?.localizedDescription
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_peripheralDisconnected", data: peripheralData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didSubscribeToCharacteristic characteristic: CBCharacteristic, central: CBCentral) {
        logger.info("🔵 Central subscribed to characteristic: \(characteristic.uuid)")
        
        let characteristicData: [String: Any] = [
            "characteristicUUID": characteristic.uuid.uuidString,
            "centralIdentifier": central.identifier.uuidString
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_characteristicSubscribed", data: characteristicData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic, central: CBCentral) {
        logger.info("🔵 Central unsubscribed from characteristic: \(characteristic.uuid)")
        
        let characteristicData: [String: Any] = [
            "characteristicUUID": characteristic.uuid.uuidString,
            "centralIdentifier": central.identifier.uuidString
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_characteristicUnsubscribed", data: characteristicData)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveData data: Data, from source: Any) {
        logger.info("🔵 Received data: \(data.count) bytes")
        
        let dataString = data.base64EncodedString()
        let sourceInfo: [String: Any] = [
            "data": dataString,
            "size": data.count,
            "source": String(describing: source)
        ]
        
        webViewBridge?.sendToWebView(event: "bluetooth_dataReceived", data: sourceInfo)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveEcashMessage message: [String: Any]) {
        logger.info("🔵 Received ecash message")
        
        webViewBridge?.sendToWebView(event: "bluetooth_ecashReceived", data: message)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didReceiveTextMessage message: [String: Any]) {
        logger.info("🔵 Received text message")
        
        webViewBridge?.sendToWebView(event: "bluetooth_textMessageReceived", data: message)
    }
    
    func bluetoothEcashService(_ service: BluetoothEcashService, didDiscoverPeer peerInfo: [String: Any]) {
        logger.info("🔵 Discovered peer: \(peerInfo["peerID"] ?? "unknown")")
        
        webViewBridge?.sendToWebView(event: "bluetooth_peerDiscovered", data: peerInfo)
    }
}
