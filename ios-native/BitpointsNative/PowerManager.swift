//
// PowerManager.swift
// bitpoints.me
//
// Power management and battery optimization for Bluetooth mesh networking
// Ported from Android PowerManager.kt
//

import Foundation
import UIKit

/// PowerManager - Manages battery optimization and adaptive duty cycling
/// Implements background/foreground mode detection, battery-aware scanning intervals, and connection throttling
final class PowerManager: NSObject {
    
    // MARK: - Constants
    
    private let lowBatteryThreshold: Float = 0.20 // 20%
    private let criticalBatteryThreshold: Float = 0.10 // 10%
    private let maxScanInterval: TimeInterval = 30.0 // 30 seconds
    private let minScanInterval: TimeInterval = 1.0 // 1 second
    private let maxConnectionsLowBattery = 3
    private let maxConnectionsNormal = 8
    private let powerUpdateInterval: TimeInterval = 60.0 // 1 minute
    
    // MARK: - Power State
    
    enum PowerMode {
        case normal
        case lowBattery
        case criticalBattery
        case background
        case foreground
    }
    
    private struct PowerState {
        var currentMode: PowerMode = .normal
        var batteryLevel: Float = 1.0
        var isCharging: Bool = false
        var lastUpdate: Date = Date()
        var scanInterval: TimeInterval = 5.0
        var maxConnections: Int = 8
        var isBackgroundMode: Bool = false
    }
    
    // MARK: - State Management
    
    private var powerState = PowerState()
    private var powerQueue = DispatchQueue(label: "me.bitpoints.wallet.power", attributes: .concurrent)
    private var updateTimer: Timer?
    
    // MARK: - Dependencies
    
    private weak var delegate: PowerManagerDelegate?
    private let connectionManager: ConnectionManager
    
    // MARK: - Initialization
    
    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        super.init()
        
        // Start power monitoring
        startPowerMonitoring()
        
        // Register for app state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        print("PowerManager: Initialized")
    }
    
    // MARK: - Power Monitoring
    
    /// Start power monitoring
    private func startPowerMonitoring() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: powerUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePowerState()
        }
        
        // Initial update
        updatePowerState()
    }
    
    /// Update power state
    private func updatePowerState() {
        powerQueue.async {
            let batteryLevel = UIDevice.current.batteryLevel
            let isCharging = UIDevice.current.batteryState == .charging
            
            var newMode: PowerMode = .normal
            
            // Determine power mode based on battery level
            if batteryLevel <= self.criticalBatteryThreshold {
                newMode = .criticalBattery
            } else if batteryLevel <= self.lowBatteryThreshold {
                newMode = .lowBattery
            } else {
                newMode = .normal
            }
            
            // Override with background mode if app is in background
            if self.powerState.isBackgroundMode {
                newMode = .background
            }
            
            // Update power state
            self.powerState.batteryLevel = batteryLevel
            self.powerState.isCharging = isCharging
            self.powerState.currentMode = newMode
            self.powerState.lastUpdate = Date()
            
            // Update power settings
            self.updatePowerSettings()
            
            print("PowerManager: Updated power state - Mode: \(newMode), Battery: \(batteryLevel), Charging: \(isCharging)")
        }
    }
    
    /// Update power settings based on current mode
    private func updatePowerSettings() {
        switch powerState.currentMode {
        case .normal:
            powerState.scanInterval = 5.0
            powerState.maxConnections = maxConnectionsNormal
            
        case .lowBattery:
            powerState.scanInterval = 10.0
            powerState.maxConnections = maxConnectionsLowBattery
            
        case .criticalBattery:
            powerState.scanInterval = 20.0
            powerState.maxConnections = 2
            
        case .background:
            powerState.scanInterval = maxScanInterval
            powerState.maxConnections = 1
            
        case .foreground:
            // Restore normal settings when returning to foreground
            if powerState.batteryLevel > lowBatteryThreshold {
                powerState.scanInterval = 5.0
                powerState.maxConnections = maxConnectionsNormal
            } else {
                powerState.scanInterval = 10.0
                powerState.maxConnections = maxConnectionsLowBattery
            }
        }
        
        // Clamp scan interval
        powerState.scanInterval = max(minScanInterval, min(maxScanInterval, powerState.scanInterval))
        
        // Notify delegate of power settings change
        DispatchQueue.main.async {
            self.delegate?.powerManager(self, didUpdatePowerSettings: self.getPowerSettings())
        }
    }
    
    // MARK: - App State Handling
    
    @objc private func appDidEnterBackground() {
        powerQueue.async {
            self.powerState.isBackgroundMode = true
            self.updatePowerSettings()
            print("PowerManager: App entered background mode")
        }
    }
    
    @objc private func appWillEnterForeground() {
        powerQueue.async {
            self.powerState.isBackgroundMode = false
            self.updatePowerSettings()
            print("PowerManager: App will enter foreground mode")
        }
    }
    
    // MARK: - Power Settings
    
    /// Get current power settings
    func getPowerSettings() -> PowerSettings {
        return powerQueue.sync {
            PowerSettings(
                scanInterval: powerState.scanInterval,
                maxConnections: powerState.maxConnections,
                powerMode: powerState.currentMode,
                batteryLevel: powerState.batteryLevel,
                isCharging: powerState.isCharging,
                isBackgroundMode: powerState.isBackgroundMode
            )
        }
    }
    
    /// Check if we can accept new connections
    func canAcceptNewConnection() -> Bool {
        return powerQueue.sync {
            let currentConnections = connectionManager.getActiveConnections().count
            return currentConnections < powerState.maxConnections
        }
    }
    
    /// Get recommended scan interval
    func getRecommendedScanInterval() -> TimeInterval {
        return powerQueue.sync {
            return powerState.scanInterval
        }
    }
    
    /// Get recommended connection timeout
    func getRecommendedConnectionTimeout() -> TimeInterval {
        return powerQueue.sync {
            switch powerState.currentMode {
            case .normal:
                return 10.0
            case .lowBattery:
                return 15.0
            case .criticalBattery:
                return 20.0
            case .background:
                return 30.0
            case .foreground:
                return 10.0
            }
        }
    }
    
    // MARK: - Battery Optimization
    
    /// Optimize for battery saving
    func optimizeForBatterySaving() {
        powerQueue.async(flags: .barrier) {
            // Reduce scan interval
            self.powerState.scanInterval = min(self.powerState.scanInterval * 1.5, self.maxScanInterval)
            
            // Reduce max connections
            self.powerState.maxConnections = max(1, self.powerState.maxConnections - 1)
            
            // Update settings
            self.updatePowerSettings()
            
            print("PowerManager: Optimized for battery saving")
        }
    }
    
    /// Optimize for performance
    func optimizeForPerformance() {
        powerQueue.async(flags: .barrier) {
            // Increase scan frequency
            self.powerState.scanInterval = max(self.powerState.scanInterval * 0.8, self.minScanInterval)
            
            // Increase max connections
            self.powerState.maxConnections = min(self.maxConnectionsNormal, self.powerState.maxConnections + 1)
            
            // Update settings
            self.updatePowerSettings()
            
            print("PowerManager: Optimized for performance")
        }
    }
    
    // MARK: - Power Statistics
    
    /// Get power statistics
    func getPowerStatistics() -> PowerStatistics {
        return powerQueue.sync {
            let activeConnections = connectionManager.getActiveConnections().count
            let connectionUtilization = powerState.maxConnections > 0 ? 
                Double(activeConnections) / Double(powerState.maxConnections) : 0.0
            
            return PowerStatistics(
                batteryLevel: powerState.batteryLevel,
                isCharging: powerState.isCharging,
                powerMode: powerState.currentMode,
                scanInterval: powerState.scanInterval,
                maxConnections: powerState.maxConnections,
                activeConnections: activeConnections,
                connectionUtilization: connectionUtilization,
                isBackgroundMode: powerState.isBackgroundMode
            )
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct PowerSettings {
    let scanInterval: TimeInterval
    let maxConnections: Int
    let powerMode: PowerManager.PowerMode
    let batteryLevel: Float
    let isCharging: Bool
    let isBackgroundMode: Bool
}

struct PowerStatistics {
    let batteryLevel: Float
    let isCharging: Bool
    let powerMode: PowerManager.PowerMode
    let scanInterval: TimeInterval
    let maxConnections: Int
    let activeConnections: Int
    let connectionUtilization: Double
    let isBackgroundMode: Bool
}

// MARK: - Delegate Protocol

protocol PowerManagerDelegate: AnyObject {
    func powerManager(_ manager: PowerManager, didUpdatePowerSettings settings: PowerSettings)
}
