import Foundation

/**
 * EcashDelegate
 *
 * Protocol for handling ecash-related events
 * Enhanced with complete mesh networking events
 */
protocol EcashDelegate: AnyObject {
    
    // MARK: - Token Events
    
    /// Called when a token is successfully sent
    func ecashService(_ service: BluetoothEcashService, didSendToken token: EcashMessage)
    
    /// Called when a token is received
    func ecashService(_ service: BluetoothEcashService, didReceiveToken token: EcashMessage)
    
    // MARK: - Peer Events
    
    /// Called when a peer is discovered
    func ecashService(_ service: BluetoothEcashService, didDiscoverPeer peer: PeerInfo)
    
    /// Called when connected to a peer
    func ecashService(_ service: BluetoothEcashService, didConnectToPeer peer: PeerInfo)
    
    /// Called when disconnected from a peer
    func ecashService(_ service: BluetoothEcashService, didDisconnectFromPeer peerID: PeerID)
    
    // MARK: - Security Events
    
    /// Called when a security event is detected
    func ecashService(_ service: BluetoothEcashService, didDetectSecurityEvent event: SecurityManager.SecurityEvent)
    
    // MARK: - Service Events
    
    /// Called when the service starts
    func ecashServiceDidStart(_ service: BluetoothEcashService)
    
    /// Called when the service stops
    func ecashServiceDidStop(_ service: BluetoothEcashService)
    
    /// Called when an error occurs
    func ecashService(_ service: BluetoothEcashService, didEncounterError error: Error)
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    func onEcashReceived(message: EcashMessage)
    func onPeerDiscovered(peer: PeerInfo)
    func onPeerLost(peerID: String)
    func onTokenSent(messageId: String)
    func onTokenDelivered(messageId: String, peerID: String)
    func onTokenSendFailed(messageId: String, reason: String)
}
