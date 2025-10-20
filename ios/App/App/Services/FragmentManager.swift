//
// FragmentManager.swift
// bitpoints.me
//
// Message fragmentation and reassembly for Bluetooth mesh networking
// Ported from Android FragmentManager.kt
//

import Foundation

/// FragmentManager - Handles message fragmentation and reassembly
/// Manages large message splitting and timeout handling
final class FragmentManager: NSObject {
    
    // MARK: - Constants
    
    private let maxFragmentSize = 512 // BLE MTU limit
    private let fragmentTimeout: TimeInterval = 30.0 // 30 seconds
    private let maxFragments = 64 // Maximum fragments per message
    private let maxInFlightAssemblies = 10 // Maximum concurrent assemblies
    
    // MARK: - Fragment State
    
    private struct FragmentInfo {
        let messageId: String
        let totalFragments: Int
        let timestamp: Date
        var receivedFragments: [Int: Data] = [:]
        var isComplete: Bool = false
    }
    
    private struct FragmentPacket {
        let messageId: String
        let fragmentIndex: Int
        let totalFragments: Int
        let data: Data
        let timestamp: Date
    }
    
    // MARK: - State Management
    
    private var fragmentAssemblies: [String: FragmentInfo] = [:]
    private var fragmentQueue = DispatchQueue(label: "me.bitpoints.wallet.fragment", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Start cleanup timer
        startCleanupTimer()
        
        print("FragmentManager: Initialized")
    }
    
    // MARK: - Message Fragmentation
    
    /// Fragment large message into smaller packets
    func fragmentMessage(_ data: Data, messageId: String) -> [Data] {
        guard data.count > maxFragmentSize else {
            // Message is small enough, return as single fragment
            return [createFragmentPacket(messageId: messageId, fragmentIndex: 0, totalFragments: 1, data: data)]
        }
        
        let totalFragments = (data.count + maxFragmentSize - 1) / maxFragmentSize
        
        guard totalFragments <= maxFragments else {
            print("FragmentManager: Message too large (\(data.count) bytes), max fragments: \(maxFragments)")
            return []
        }
        
        var fragments: [Data] = []
        
        for i in 0..<totalFragments {
            let startIndex = i * maxFragmentSize
            let endIndex = min(startIndex + maxFragmentSize, data.count)
            let fragmentData = data.subdata(in: startIndex..<endIndex)
            
            let fragmentPacket = createFragmentPacket(
                messageId: messageId,
                fragmentIndex: i,
                totalFragments: totalFragments,
                data: fragmentData
            )
            
            fragments.append(fragmentPacket)
        }
        
        print("FragmentManager: Fragmented message \(messageId) into \(totalFragments) fragments")
        return fragments
    }
    
    /// Create fragment packet
    private func createFragmentPacket(messageId: String, fragmentIndex: Int, totalFragments: Int, data: Data) -> Data {
        var packet = Data()
        
        // Message ID (8 bytes)
        let messageIdData = messageId.prefix(8).data(using: .utf8) ?? Data(count: 8)
        packet.append(messageIdData)
        if messageIdData.count < 8 {
            packet.append(Data(count: 8 - messageIdData.count))
        }
        
        // Fragment index (1 byte)
        packet.append(UInt8(fragmentIndex))
        
        // Total fragments (1 byte)
        packet.append(UInt8(totalFragments))
        
        // Fragment data
        packet.append(data)
        
        return packet
    }
    
    // MARK: - Fragment Reassembly
    
    /// Process incoming fragment
    func processFragment(_ data: Data, from sender: PeerID, completion: @escaping (Data?) -> Void) {
        fragmentQueue.async {
            do {
                let fragmentPacket = try self.parseFragmentPacket(data)
                
                // Check if we can accept more assemblies
                if self.fragmentAssemblies.count >= self.maxInFlightAssemblies {
                    print("FragmentManager: Too many in-flight assemblies, dropping fragment")
                    completion(nil)
                    return
                }
                
                // Get or create fragment assembly
                var fragmentInfo = self.fragmentAssemblies[fragmentPacket.messageId] ?? FragmentInfo(
                    messageId: fragmentPacket.messageId,
                    totalFragments: fragmentPacket.totalFragments,
                    timestamp: fragmentPacket.timestamp
                )
                
                // Add fragment
                fragmentInfo.receivedFragments[fragmentPacket.fragmentIndex] = fragmentPacket.data
                
                // Check if assembly is complete
                if fragmentInfo.receivedFragments.count == fragmentPacket.totalFragments {
                    fragmentInfo.isComplete = true
                    
                    // Reassemble message
                    let completeMessage = self.reassembleMessage(fragmentInfo)
                    
                    // Remove from assemblies
                    self.fragmentAssemblies.removeValue(forKey: fragmentPacket.messageId)
                    
                    print("FragmentManager: Reassembled message \(fragmentPacket.messageId)")
                    completion(completeMessage)
                } else {
                    // Update assembly
                    self.fragmentAssemblies[fragmentPacket.messageId] = fragmentInfo
                    completion(nil)
                }
                
            } catch {
                print("FragmentManager: Error processing fragment: \(error)")
                completion(nil)
            }
        }
    }
    
    /// Parse fragment packet
    private func parseFragmentPacket(_ data: Data) throws -> FragmentPacket {
        guard data.count >= 10 else {
            throw FragmentError.invalidPacketSize
        }
        
        // Message ID (8 bytes)
        let messageIdData = data.subdata(in: 0..<8)
        let messageId = String(data: messageIdData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? ""
        
        // Fragment index (1 byte)
        let fragmentIndex = Int(data[8])
        
        // Total fragments (1 byte)
        let totalFragments = Int(data[9])
        
        // Fragment data
        let fragmentData = data.subdata(in: 10..<data.count)
        
        return FragmentPacket(
            messageId: messageId,
            fragmentIndex: fragmentIndex,
            totalFragments: totalFragments,
            data: fragmentData,
            timestamp: Date()
        )
    }
    
    /// Reassemble message from fragments
    private func reassembleMessage(_ fragmentInfo: FragmentInfo) -> Data {
        var messageData = Data()
        
        // Sort fragments by index
        let sortedFragments = fragmentInfo.receivedFragments.sorted { $0.key < $1.key }
        
        for (_, fragmentData) in sortedFragments {
            messageData.append(fragmentData)
        }
        
        return messageData
    }
    
    // MARK: - Fragment Validation
    
    /// Check if data needs fragmentation
    func needsFragmentation(_ data: Data) -> Bool {
        return data.count > maxFragmentSize
    }
    
    /// Get optimal fragment size for given data
    func getOptimalFragmentSize(for data: Data) -> Int {
        if data.count <= maxFragmentSize {
            return data.count
        }
        
        let totalFragments = (data.count + maxFragmentSize - 1) / maxFragmentSize
        return (data.count + totalFragments - 1) / totalFragments
    }
    
    // MARK: - Cleanup
    
    /// Start cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.cleanupExpiredFragments()
        }
    }
    
    /// Clean up expired fragments
    private func cleanupExpiredFragments() {
        fragmentQueue.async(flags: .barrier) {
            let cutoffTime = Date().addingTimeInterval(-self.fragmentTimeout)
            
            let expiredAssemblies = self.fragmentAssemblies.filter { _, info in
                info.timestamp < cutoffTime && !info.isComplete
            }
            
            for (messageId, _) in expiredAssemblies {
                self.fragmentAssemblies.removeValue(forKey: messageId)
            }
            
            if !expiredAssemblies.isEmpty {
                print("FragmentManager: Cleaned up \(expiredAssemblies.count) expired fragment assemblies")
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get fragment statistics
    func getFragmentStatistics() -> FragmentStatistics {
        return fragmentQueue.sync {
            let activeAssemblies = fragmentAssemblies.count
            let completeFragments = fragmentAssemblies.values.reduce(0) { $0 + $1.receivedFragments.count }
            let totalFragments = fragmentAssemblies.values.reduce(0) { $0 + $1.totalFragments }
            
            return FragmentStatistics(
                activeAssemblies: activeAssemblies,
                completeFragments: completeFragments,
                totalFragments: totalFragments,
                completionRate: totalFragments > 0 ? Double(completeFragments) / Double(totalFragments) : 0.0
            )
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
}

// MARK: - Supporting Types

struct FragmentStatistics {
    let activeAssemblies: Int
    let completeFragments: Int
    let totalFragments: Int
    let completionRate: Double
}

// MARK: - Errors

enum FragmentError: Error {
    case invalidPacketSize
    case invalidFragmentIndex
    case invalidTotalFragments
    case messageTooLarge
    case assemblyTimeout
    case tooManyFragments
}
