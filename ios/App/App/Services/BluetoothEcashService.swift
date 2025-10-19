import Foundation
import CoreBluetooth

/**
 * BluetoothEcashService
 *
 * Main service for handling Bluetooth ecash operations
 * iOS equivalent of Android's BluetoothEcashService.kt
 */
class BluetoothEcashService: BLEServiceDelegate {

    weak var delegate: EcashDelegate?

    private var isServiceActive = false
    private var activePeers: [String: PeerInfo] = [:]
    private var unclaimedTokens: [EcashMessage] = []
    private var nickname: String = "Bitpoints User"

    private let bleService: BLEService
    private let noiseService: NoiseEncryptionService
    private let keychain: KeychainManagerProtocol

    init() {
        print("BluetoothEcashService initialized")

        // Initialize keychain
        self.keychain = KeychainManager()

        // Initialize noise service
        self.noiseService = NoiseEncryptionService(keychain: keychain)

        // Initialize BLE service
        self.bleService = BLEService(noiseService: noiseService, keychain: keychain)
        self.bleService.delegate = self

        // Set up noise service callbacks
        noiseService.onHandshakeRequired = { [weak self] peerID in
            self?.initiateHandshake(with: peerID)
        }
    }

    // MARK: - Service Control

    func startService(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 Starting Bluetooth ecash service")

        bleService.startService()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isServiceActive = true
            completion(.success(()))
        }
    }

    func stopService(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🛑 Stopping Bluetooth ecash service")

        bleService.stopService()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isServiceActive = false
            completion(.success(()))
        }
    }

    // MARK: - Token Operations

    func sendToken(token: String,
                  toPeer: String,
                  amount: Int,
                  unit: String,
                  memo: String?,
                  completion: @escaping (Result<String, Error>) -> Void) {
        print("🚀 sendToken called from frontend")
        print("📦 Token received: \(token.prefix(20))...")
        print("Sending ecash token to peer \(toPeer)")

        let messageId = UUID().uuidString

        // Create ecash message
        let ecashMessage = EcashMessage(
            id: messageId,
            sender: noiseService.getIdentityFingerprint(),
            amount: amount,
            unit: unit,
            cashuToken: token,
            mint: "", // TODO: Extract mint from token
            memo: memo
        )

        // Convert to binary payload
        guard let messageData = ecashMessage.toBinaryPayload() else {
            completion(.failure(NSError(domain: "BluetoothEcashService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode ecash message"])))
            return
        }

        // Create peer ID
        let peerID = PeerID(str: toPeer)

        // Send via BLE service
        bleService.sendMessage(messageData, to: peerID)

        // Notify delegate
        delegate?.onTokenSent(messageId: messageId)

        // Simulate delivery (in real implementation, this would be confirmed by the recipient)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.delegate?.onTokenDelivered(messageId: messageId, peerID: toPeer)
            completion(.success(messageId))
        }
    }

    func getActivePeers() -> [PeerInfo] {
        let blePeers = bleService.getActivePeers()
        return blePeers.map { blePeer in
            PeerInfo(
                id: blePeer.peerID.id,
                nickname: blePeer.nickname,
                lastSeen: blePeer.lastSeen,
                isDirect: true, // BLE is always direct
                nostrNpub: nil,
                isConnected: blePeer.isConnected
            )
        }
    }

    func getUnclaimedTokens() -> [EcashMessage] {
        return unclaimedTokens.filter { !$0.claimed }
    }

    func markTokenClaimed(_ messageId: String) {
        if let index = unclaimedTokens.firstIndex(where: { $0.id == messageId }) {
            unclaimedTokens[index].claimed = true
        }
    }

    // MARK: - Identity Management

    func setNickname(_ nickname: String) {
        self.nickname = nickname
    }

    func getNickname() -> String {
        return nickname
    }

    // MARK: - Bluetooth Status

    func isBluetoothEnabled() -> Bool {
        // TODO: Check actual Bluetooth state
        return true
    }

    func requestBluetoothEnable(completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Request Bluetooth enable
        completion(.success(()))
    }

    func requestPermissions(completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Request Bluetooth permissions
        completion(.success(()))
    }

    // MARK: - Handshake Management

    private func initiateHandshake(with peerID: PeerID) {
        do {
            let handshakeData = try noiseService.initiateHandshake(with: peerID)
            bleService.sendMessage(handshakeData, to: peerID)
        } catch {
            print("BluetoothEcashService: Failed to initiate handshake: \(error)")
        }
    }

    // MARK: - BLEServiceDelegate

    func didDiscoverPeer(_ peerID: PeerID) {
        print("BluetoothEcashService: Discovered peer: \(peerID)")

        let peerInfo = PeerInfo(
            id: peerID.id,
            nickname: "Unknown",
            lastSeen: Date(),
            isDirect: true,
            nostrNpub: nil,
            isConnected: false
        )

        delegate?.onPeerDiscovered(peer: peerInfo)
    }

    func didUpdatePeerConnection(_ peerID: PeerID, isConnected: Bool) {
        print("BluetoothEcashService: Peer \(peerID) connection status: \(isConnected)")

        if !isConnected {
            delegate?.onPeerLost(peerID: peerID.id)
        }
    }

    func didReceiveMessage(_ data: Data, from peerID: PeerID) {
        print("BluetoothEcashService: Received message from \(peerID)")

        // Try to decode as ecash message
        if let ecashMessage = EcashMessage.fromBinaryPayload(data) {
            print("BluetoothEcashService: Received ecash token: \(ecashMessage.id)")
            unclaimedTokens.append(ecashMessage)
            delegate?.onEcashReceived(message: ecashMessage)
        } else {
            // Try to process as handshake message
            do {
                let response = try noiseService.processHandshakeMessage(from: peerID, message: data)
                if let responseData = response {
                    bleService.sendMessage(responseData, to: peerID)
                }
            } catch {
                print("BluetoothEcashService: Failed to process message: \(error)")
            }
        }
    }
}
