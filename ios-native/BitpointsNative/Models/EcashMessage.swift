import Foundation

/**
 * EcashMessage
 *
 * Represents an ecash token message for Bluetooth transmission
 * Equivalent to Android's EcashMessage.kt
 */
struct EcashMessage: Codable {
    let id: String
    let sender: String
    let amount: Int
    let unit: String
    let cashuToken: String
    let mint: String
    let memo: String?
    let timestamp: Date
    var claimed: Bool

    init(id: String = UUID().uuidString,
         sender: String,
         amount: Int,
         unit: String,
         cashuToken: String,
         mint: String,
         memo: String? = nil,
         timestamp: Date = Date(),
         claimed: Bool = false) {
        self.id = id
        self.sender = sender
        self.amount = amount
        self.unit = unit
        self.cashuToken = cashuToken
        self.mint = mint
        self.memo = memo
        self.timestamp = timestamp
        self.claimed = claimed
    }

    /**
     * Convert to binary payload for transmission
     */
    func toBinaryPayload() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try? encoder.encode(self)
    }

    /**
     * Create from binary payload
     */
    static func fromBinaryPayload(_ data: Data) -> EcashMessage? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(EcashMessage.self, from: data)
    }
}
