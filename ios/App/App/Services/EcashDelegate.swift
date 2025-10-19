import Foundation

/**
 * EcashDelegate
 *
 * Protocol for handling ecash-related events
 * Equivalent to Android's EcashDelegate interface
 */
protocol EcashDelegate: AnyObject {
    func onEcashReceived(message: EcashMessage)
    func onPeerDiscovered(peer: PeerInfo)
    func onPeerLost(peerID: String)
    func onTokenSent(messageId: String)
    func onTokenDelivered(messageId: String, peerID: String)
    func onTokenSendFailed(messageId: String, reason: String)
}
