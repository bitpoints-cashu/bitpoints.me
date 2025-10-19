import Foundation

/**
 * PeerInfo
 *
 * Represents information about a discovered peer
 * Equivalent to Android's PeerInfo.kt
 */
struct PeerInfo {
    let id: String
    var nickname: String
    var isConnected: Bool
    var isDirectConnection: Bool
    var nostrNpub: String?
    var lastSeen: Date

    init(id: String,
         nickname: String = "Unknown",
         isConnected: Bool = false,
         isDirectConnection: Bool = false,
         nostrNpub: String? = nil,
         lastSeen: Date = Date()) {
        self.id = id
        self.nickname = nickname
        self.isConnected = isConnected
        self.isDirectConnection = isDirectConnection
        self.nostrNpub = nostrNpub
        self.lastSeen = lastSeen
    }
}
