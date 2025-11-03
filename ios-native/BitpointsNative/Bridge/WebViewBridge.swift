import Foundation
import WebKit
import os.log

class WebViewBridge: NSObject, ObservableObject, WKScriptMessageHandler {
    private let logger = Logger(subsystem: "me.bitpoints.native", category: "WebViewBridge")
    
    weak var bluetoothService: BluetoothEcashService?
    weak var webView: WKWebView?
    
    // Callback storage for async operations
    private var callbacks: [String: (Result<Any, Error>) -> Void] = [:]
    
    func userContentController(_ userContentController: WKUserContentController, 
                              didReceive message: WKScriptMessage) {
        logger.info("🔵 Received message from JavaScript: \(message.name)")
        
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            logger.error("🔵 Invalid message format")
            return
        }
        
        logger.info("🔵 Action: \(action)")
        
        switch action {
        case "startBluetoothService":
            handleStartBluetooth(body)
        case "stopBluetoothService":
            handleStopBluetooth(body)
        case "sendToken":
            handleSendToken(body)
        case "getAvailablePeers":
            handleGetAvailablePeers(body)
        case "getUnclaimedTokens":
            handleGetUnclaimedTokens(body)
        case "markTokenClaimed":
            handleMarkTokenClaimed(body)
        case "setNickname":
            handleSetNickname(body)
        case "getNickname":
            handleGetNickname(body)
        case "isBluetoothEnabled":
            handleIsBluetoothEnabled(body)
        case "requestBluetoothEnable":
            handleRequestBluetoothEnable(body)
        case "requestPermissions":
            handleRequestPermissions(body)
        case "sendTextMessage":
            handleSendTextMessage(body)
        default:
            logger.warning("🔵 Unknown action: \(action)")
            sendErrorToWebView(action: action, error: "Unknown action: \(action)")
        }
    }
    
    // MARK: - Bluetooth Service Handlers
    
    private func handleStartBluetooth(_ params: [String: Any]) {
        logger.info("🔵 Starting Bluetooth service")
        
        bluetoothService?.startService { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🔵 Bluetooth service started successfully")
                self?.sendToWebView(event: "bluetooth_started", data: [:])
            case .failure(let error):
                self?.logger.error("🔵 Failed to start Bluetooth service: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "startBluetoothService", error: error.localizedDescription)
            }
        }
    }
    
    private func handleStopBluetooth(_ params: [String: Any]) {
        logger.info("🔵 Stopping Bluetooth service")
        
        bluetoothService?.stopService { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🔵 Bluetooth service stopped successfully")
                self?.sendToWebView(event: "bluetooth_stopped", data: [:])
            case .failure(let error):
                self?.logger.error("🔵 Failed to stop Bluetooth service: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "stopBluetoothService", error: error.localizedDescription)
            }
        }
    }
    
    private func handleSendToken(_ params: [String: Any]) {
        logger.info("🔵 Sending token via Bluetooth")
        
        guard let options = params["options"] as? [String: Any] else {
            sendErrorToWebView(action: "sendToken", error: "Missing options parameter")
            return
        }
        
        bluetoothService?.sendToken(options) { [weak self] result in
            switch result {
            case .success(let messageId):
                self?.logger.info("🔵 Token sent successfully: \(messageId)")
                self?.sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                                           data: ["messageId": messageId])
            case .failure(let error):
                self?.logger.error("🔵 Failed to send token: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "sendToken", error: error.localizedDescription)
            }
        }
    }
    
    private func handleGetAvailablePeers(_ params: [String: Any]) {
        logger.info("🔵 Getting available peers")
        
        let peers = bluetoothService?.getAvailablePeers() ?? []
        sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                             data: ["peers": peers])
    }
    
    private func handleGetUnclaimedTokens(_ params: [String: Any]) {
        logger.info("🔵 Getting unclaimed tokens")
        
        let tokens = bluetoothService?.getUnclaimedTokens() ?? []
        sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                             data: ["tokens": tokens])
    }
    
    private func handleMarkTokenClaimed(_ params: [String: Any]) {
        logger.info("🔵 Marking token as claimed")
        
        guard let messageId = params["messageId"] as? String else {
            sendErrorToWebView(action: "markTokenClaimed", error: "Missing messageId parameter")
            return
        }
        
        bluetoothService?.markTokenClaimed(messageId: messageId) { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🔵 Token marked as claimed: \(messageId)")
                self?.sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                                           data: [:])
            case .failure(let error):
                self?.logger.error("🔵 Failed to mark token as claimed: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "markTokenClaimed", error: error.localizedDescription)
            }
        }
    }
    
    private func handleSetNickname(_ params: [String: Any]) {
        logger.info("🔵 Setting nickname")
        
        guard let nickname = params["nickname"] as? String else {
            sendErrorToWebView(action: "setNickname", error: "Missing nickname parameter")
            return
        }
        
        bluetoothService?.setNickname(nickname) { [weak self] result in
            switch result {
            case .success(let newNickname):
                self?.logger.info("🔵 Nickname set successfully: \(newNickname)")
                self?.sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                                           data: ["nickname": newNickname])
            case .failure(let error):
                self?.logger.error("🔵 Failed to set nickname: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "setNickname", error: error.localizedDescription)
            }
        }
    }
    
    private func handleGetNickname(_ params: [String: Any]) {
        logger.info("🔵 Getting nickname")
        
        let nickname = bluetoothService?.getNickname() ?? ""
        sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                             data: ["nickname": nickname])
    }
    
    private func handleIsBluetoothEnabled(_ params: [String: Any]) {
        logger.info("🔵 Checking if Bluetooth is enabled")
        
        let isEnabled = bluetoothService?.isBluetoothEnabled() ?? false
        sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                             data: ["enabled": isEnabled])
    }
    
    private func handleRequestBluetoothEnable(_ params: [String: Any]) {
        logger.info("🔵 Requesting Bluetooth enable")
        
        bluetoothService?.requestBluetoothEnable { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🔵 Bluetooth enable requested successfully")
                self?.sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                                           data: ["requested": true])
            case .failure(let error):
                self?.logger.error("🔵 Failed to request Bluetooth enable: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "requestBluetoothEnable", error: error.localizedDescription)
            }
        }
    }
    
    private func handleRequestPermissions(_ params: [String: Any]) {
        logger.info("🔵 Requesting permissions")
        
        bluetoothService?.requestPermissions { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🔵 Permissions granted")
                self?.sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                                           data: ["granted": true])
            case .failure(let error):
                self?.logger.error("🔵 Permissions denied: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "requestPermissions", error: error.localizedDescription)
            }
        }
    }
    
    private func handleSendTextMessage(_ params: [String: Any]) {
        logger.info("🔵 Sending text message")
        
        guard let peerID = params["peerID"] as? String,
              let message = params["message"] as? String else {
            sendErrorToWebView(action: "sendTextMessage", error: "Missing peerID or message parameter")
            return
        }
        
        bluetoothService?.sendTextMessage(message: message, toPeer: peerID) { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🔵 Text message sent successfully")
                self?.sendCallbackToWebView(callbackId: params["callbackId"] as? String, 
                                           data: [:])
            case .failure(let error):
                self?.logger.error("🔵 Failed to send text message: \(error.localizedDescription)")
                self?.sendErrorToWebView(action: "sendTextMessage", error: error.localizedDescription)
            }
        }
    }
    
    // MARK: - WebView Communication
    
    func sendToWebView(event: String, data: [String: Any]) {
        guard let webView = webView else {
            logger.error("🔵 WebView not available for sending event: \(event)")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let script = "window.dispatchEvent(new CustomEvent('\(event)', {detail: \(jsonString)}))"
            
            DispatchQueue.main.async {
                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        self.logger.error("🔵 Failed to send event to WebView: \(error.localizedDescription)")
                    } else {
                        self.logger.info("🔵 Event sent to WebView: \(event)")
                    }
                }
            }
        } catch {
            logger.error("🔵 Failed to serialize data for event \(event): \(error.localizedDescription)")
        }
    }
    
    private func sendCallbackToWebView(callbackId: String?, data: [String: Any]) {
        guard let callbackId = callbackId else {
            logger.warning("🔵 No callback ID provided")
            return
        }
        
        sendToWebView(event: "bluetooth_callback_\(callbackId)", data: data)
    }
    
    private func sendErrorToWebView(action: String, error: String) {
        sendToWebView(event: "bluetooth_error", data: [
            "action": action,
            "error": error
        ])
    }
}
