//
// ConnectionManager.swift
// bitpoints.me
//
// Connection management for Bluetooth mesh networking
// Ported from Android BluetoothConnectionManager.kt
//

import Foundation
import CoreBluetooth

/// ConnectionManager - Tracks active connections and manages connection limits
/// Handles connection state machine and reconnection logic
final class ConnectionManager: NSObject {
    
    // MARK: - Constants
    
    private let maxConcurrentConnections = 8
    private let connectionTimeout: TimeInterval = 10.0
    private let reconnectionDelay: TimeInterval = 5.0
    private let maxReconnectionAttempts = 3
    
    // MARK: - Connection State
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case disconnecting
        case failed
    }
    
    private struct ConnectionInfo {
        let peerID: PeerID
        let peripheral: CBPeripheral
        var state: ConnectionState
        var connectionAttempts: Int
        var lastConnectionAttempt: Date?
        var lastSeen: Date
        var isReconnecting: Bool
    }
    
    // MARK: - State Management
    
    private var connections: [PeerID: ConnectionInfo] = [:]
    private var connectionQueue = DispatchQueue(label: "me.bitpoints.wallet.connection", attributes: .concurrent)
    private var reconnectionTimers: [PeerID: Timer] = [:]
    
    // MARK: - Delegate
    
    weak var delegate: ConnectionManagerDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        print("ConnectionManager: Initialized")
    }
    
    // MARK: - Connection Management
    
    /// Add a new connection attempt
    func addConnection(peerID: PeerID, peripheral: CBPeripheral) {
        connectionQueue.async(flags: .barrier) {
            let connectionInfo = ConnectionInfo(
                peerID: peerID,
                peripheral: peripheral,
                state: .connecting,
                connectionAttempts: 1,
                lastConnectionAttempt: Date(),
                lastSeen: Date(),
                isReconnecting: false
            )
            
            self.connections[peerID] = connectionInfo
            print("ConnectionManager: Added connection for peer \(peerID)")
            
            DispatchQueue.main.async {
                self.delegate?.connectionManager(self, didAddConnection: peerID)
            }
        }
    }
    
    /// Update connection state
    func updateConnectionState(peerID: PeerID, state: ConnectionState) {
        connectionQueue.async(flags: .barrier) {
            guard var connectionInfo = self.connections[peerID] else {
                print("ConnectionManager: Warning - updating state for unknown peer \(peerID)")
                return
            }
            
            connectionInfo.state = state
            connectionInfo.lastSeen = Date()
            
            if state == .connected {
                connectionInfo.connectionAttempts = 0
                connectionInfo.isReconnecting = false
                self.cancelReconnectionTimer(for: peerID)
            }
            
            self.connections[peerID] = connectionInfo
            
            print("ConnectionManager: Updated state for peer \(peerID) to \(state)")
            
            DispatchQueue.main.async {
                self.delegate?.connectionManager(self, didUpdateConnection: peerID, state: state)
            }
        }
    }
    
    /// Remove connection
    func removeConnection(peerID: PeerID) {
        connectionQueue.async(flags: .barrier) {
            self.connections.removeValue(forKey: peerID)
            self.cancelReconnectionTimer(for: peerID)
            
            print("ConnectionManager: Removed connection for peer \(peerID)")
            
            DispatchQueue.main.async {
                self.delegate?.connectionManager(self, didRemoveConnection: peerID)
            }
        }
    }
    
    /// Check if we can accept new connections
    func canAcceptNewConnection() -> Bool {
        return connectionQueue.sync {
            let activeConnections = connections.values.filter { 
                $0.state == .connected || $0.state == .connecting 
            }
            return activeConnections.count < maxConcurrentConnections
        }
    }
    
    /// Get all active connections
    func getActiveConnections() -> [PeerID] {
        return connectionQueue.sync {
            return connections.compactMap { peerID, info in
                (info.state == .connected) ? peerID : nil
            }
        }
    }
    
    /// Get connection info for peer
    func getConnectionInfo(for peerID: PeerID) -> ConnectionInfo? {
        return connectionQueue.sync {
            return connections[peerID]
        }
    }
    
    // MARK: - Reconnection Logic
    
    /// Handle connection failure
    func handleConnectionFailure(peerID: PeerID) {
        connectionQueue.async(flags: .barrier) {
            guard var connectionInfo = self.connections[peerID] else { return }
            
            connectionInfo.state = .failed
            connectionInfo.connectionAttempts += 1
            
            self.connections[peerID] = connectionInfo
            
            // Schedule reconnection if under limit
            if connectionInfo.connectionAttempts <= self.maxReconnectionAttempts {
                self.scheduleReconnection(for: peerID)
            } else {
                print("ConnectionManager: Max reconnection attempts reached for peer \(peerID)")
                DispatchQueue.main.async {
                    self.delegate?.connectionManager(self, didFailConnection: peerID, error: ConnectionError.maxAttemptsReached)
                }
            }
        }
    }
    
    /// Schedule reconnection attempt
    private func scheduleReconnection(for peerID: PeerID) {
        cancelReconnectionTimer(for: peerID)
        
        let timer = Timer.scheduledTimer(withTimeInterval: reconnectionDelay, repeats: false) { [weak self] _ in
            self?.attemptReconnection(for: peerID)
        }
        
        reconnectionTimers[peerID] = timer
        print("ConnectionManager: Scheduled reconnection for peer \(peerID)")
    }
    
    /// Cancel reconnection timer
    private func cancelReconnectionTimer(for peerID: PeerID) {
        reconnectionTimers[peerID]?.invalidate()
        reconnectionTimers.removeValue(forKey: peerID)
    }
    
    /// Attempt reconnection
    private func attemptReconnection(for peerID: PeerID) {
        connectionQueue.async(flags: .barrier) {
            guard var connectionInfo = self.connections[peerID] else { return }
            
            connectionInfo.isReconnecting = true
            connectionInfo.lastConnectionAttempt = Date()
            
            self.connections[peerID] = connectionInfo
            
            print("ConnectionManager: Attempting reconnection for peer \(peerID)")
            
            DispatchQueue.main.async {
                self.delegate?.connectionManager(self, shouldReconnect: peerID, peripheral: connectionInfo.peripheral)
            }
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up old connections
    func cleanupOldConnections() {
        connectionQueue.async(flags: .barrier) {
            let cutoffTime = Date().addingTimeInterval(-300) // 5 minutes ago
            
            let oldConnections = self.connections.filter { _, info in
                info.lastSeen < cutoffTime && info.state != .connected
            }
            
            for (peerID, _) in oldConnections {
                self.removeConnection(peerID: peerID)
            }
            
            if !oldConnections.isEmpty {
                print("ConnectionManager: Cleaned up \(oldConnections.count) old connections")
            }
        }
    }
    
    deinit {
        // Cancel all timers
        for timer in reconnectionTimers.values {
            timer.invalidate()
        }
        reconnectionTimers.removeAll()
    }
}

// MARK: - Delegate Protocol

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didAddConnection peerID: PeerID)
    func connectionManager(_ manager: ConnectionManager, didUpdateConnection peerID: PeerID, state: ConnectionManager.ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didRemoveConnection peerID: PeerID)
    func connectionManager(_ manager: ConnectionManager, didFailConnection peerID: PeerID, error: Error)
    func connectionManager(_ manager: ConnectionManager, shouldReconnect peerID: PeerID, peripheral: CBPeripheral)
}

// MARK: - Errors

enum ConnectionError: Error {
    case maxAttemptsReached
    case connectionTimeout
    case peerNotFound
    case connectionLimitReached
}
