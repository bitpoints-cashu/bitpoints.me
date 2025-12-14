import Foundation
import Capacitor
import CoreBluetooth
import UIKit

@objc(BluetoothEcashPlugin)
public class BluetoothEcashPlugin: CAPPlugin {
    private let implementation = BluetoothEcash()

    public override func load() {
        implementation.delegate = self
    }

    @objc func isBluetoothEnabled(_ call: CAPPluginCall) {
        call.resolve(["enabled": implementation.isBluetoothEnabled()])
    }

    @objc func requestBluetoothEnable(_ call: CAPPluginCall) {
        implementation.requestBluetoothEnable { enabled in
            call.resolve(["enabled": enabled])
        }
    }

    @objc public override func requestPermissions(_ call: CAPPluginCall) {
        implementation.requestPermissions { granted in
            call.resolve(["granted": granted])
        }
    }

    @objc func startService(_ call: CAPPluginCall) {
        do {
            implementation.startService()
            call.resolve()
        } catch {
            call.reject("Failed to start service", error.localizedDescription, error)
        }
    }

    @objc func stopService(_ call: CAPPluginCall) {
        implementation.stopService()
        call.resolve()
    }

    @objc func setNickname(_ call: CAPPluginCall) {
        guard let nickname = call.getString("nickname") else {
            call.reject("nickname is required")
            return
        }
        implementation.setNickname(nickname)
        call.resolve(["nickname": nickname])
    }

    @objc func getNickname(_ call: CAPPluginCall) {
        let nickname = implementation.getNickname()
        call.resolve(["nickname": nickname])
    }

    @objc func getAvailablePeers(_ call: CAPPluginCall) {
        let peers = implementation.getAvailablePeers()
        call.resolve(["peers": peers])
    }

    @objc func getUnclaimedTokens(_ call: CAPPluginCall) {
        let tokens = implementation.getUnclaimedTokens()
        call.resolve(["tokens": tokens])
    }

    @objc func markTokenClaimed(_ call: CAPPluginCall) {
        guard let messageId = call.getString("messageId") else {
            call.reject("messageId is required")
            return
        }
        implementation.markTokenClaimed(messageId: messageId)
        call.resolve()
    }

    @objc func sendToken(_ call: CAPPluginCall) {
        guard let token = call.getString("token") else {
            call.reject("token is required")
            return
        }
        let recipient = call.getString("recipientID")
        let amount = call.getInt("amount") ?? 0
        let unit = call.getString("unit") ?? ""
        let memo = call.getString("memo") ?? ""
        let senderNpub = call.getString("senderNpub") ?? ""

        implementation.sendToken(token: token,
                                 amount: amount,
                                 unit: unit,
                                 memo: memo,
                                 recipientID: recipient,
                                 senderNpub: senderNpub)
        call.resolve()
    }

    @objc func sendTextMessage(_ call: CAPPluginCall) {
        guard let peerID = call.getString("peerID"),
              let message = call.getString("message") else {
            call.reject("peerID and message are required")
            return
        }
        implementation.sendTextMessage(peerID: peerID, message: message)
        call.resolve()
    }
}

extension BluetoothEcashPlugin: BluetoothEcashDelegate {
    public func emit(event: String, data: [String: Any]) {
        notifyListeners(event, data: data)
    }
}
