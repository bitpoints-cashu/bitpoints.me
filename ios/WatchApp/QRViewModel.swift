import Foundation
import Combine

@MainActor
final class QRViewModel: ObservableObject {
    @Published var qrImage: QRImage?
    @Published var pubkeyHex: String = "watch-placeholder"
    @Published var lastUpdated: Date = Date()
    @Published var errorMessage: String?

    init() {
        Task { await regenerate() }
    }

    func regenerate() async {
        // Minimal stub: generate a simple payload without external deps
        let payload = "bitpoints-watch:\(Int(Date().timeIntervalSince1970))"
        qrImage = QRImageGenerator.makeQR(from: payload, size: 220)
        lastUpdated = Date()
        errorMessage = nil
    }
}

