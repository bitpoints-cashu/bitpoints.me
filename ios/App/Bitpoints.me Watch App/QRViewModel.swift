import Foundation
import Combine
import SharedNostrCore

@MainActor
final class QRViewModel: ObservableObject {
    @Published var qrImage: QRImage?
    @Published var pubkeyHex: String = ""
    @Published var lastUpdated: Date = Date()
    @Published var errorMessage: String?

    private let keyManager = NostrKeyManager.shared
    private let builder = QRPayloadBuilder()

    init() {
        Task {
            await regenerate()
        }
    }

    func regenerate() async {
        do {
            let keys = try keyManager.loadOrCreateKeypair()
            pubkeyHex = keys.publicKeyHex
            let messageID = UUID().uuidString
            let content = "watch:ready:\(Int(Date().timeIntervalSince1970))"
            guard let result = builder.buildPayload(
                mode: .bitchatPrivateMessage(messageID: messageID, content: content, recipient: nil),
                senderPeerIdHex: keys.publicKeyHex
            ) else {
                throw NSError(domain: "QRViewModel", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to build payload"])
            }
            qrImage = QRImageGenerator.makeQR(from: result.payload, size: 220)
            lastUpdated = result.createdAt
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

