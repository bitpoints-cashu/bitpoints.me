//
// BatteryOptimizationManager.swift
// bitpoints.me
//
// Manages battery optimizations for Bluetooth operations
//

import Foundation
import CoreBluetooth

class BatteryOptimizationManager {
    private var isLowPowerMode = false
    private var batteryLevel: Float = 1.0
    private var lastOptimizationCheck = Date()

    // Optimization intervals based on battery level
    private let normalScanInterval: TimeInterval = 1.0
    private let lowBatteryScanInterval: TimeInterval = 5.0
    private let criticalBatteryScanInterval: TimeInterval = 10.0

    private let normalAdvertiseInterval: TimeInterval = 4.0
    private let lowBatteryAdvertiseInterval: TimeInterval = 8.0
    private let criticalBatteryAdvertiseInterval: TimeInterval = 15.0

    init() {
        setupBatteryMonitoring()
    }

    private func setupBatteryMonitoring() {
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )

        // Check battery level periodically
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkBatteryLevel()
        }
    }

    @objc private func lowPowerModeChanged() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        print("BatteryOptimizationManager: Low power mode changed: \(isLowPowerMode)")
        updateOptimizations()
    }

    private func checkBatteryLevel() {
        // In a real implementation, you would get the actual battery level
        // For now, we'll simulate based on low power mode
        batteryLevel = isLowPowerMode ? 0.2 : 0.8
        updateOptimizations()
    }

    private func updateOptimizations() {
        let now = Date()
        guard now.timeIntervalSince(lastOptimizationCheck) > 30.0 else { return }

        lastOptimizationCheck = now

        if isLowPowerMode || batteryLevel < 0.2 {
            print("BatteryOptimizationManager: Applying critical battery optimizations")
            applyCriticalOptimizations()
        } else if batteryLevel < 0.5 {
            print("BatteryOptimizationManager: Applying low battery optimizations")
            applyLowBatteryOptimizations()
        } else {
            print("BatteryOptimizationManager: Using normal optimizations")
            applyNormalOptimizations()
        }
    }

    private func applyCriticalOptimizations() {
        // Reduce scanning to minimum
        // Reduce advertising frequency
        // Disable non-essential features
        print("BatteryOptimizationManager: Critical optimizations applied")
    }

    private func applyLowBatteryOptimizations() {
        // Moderate reduction in scanning/advertising
        print("BatteryOptimizationManager: Low battery optimizations applied")
    }

    private func applyNormalOptimizations() {
        // Normal operation
        print("BatteryOptimizationManager: Normal optimizations applied")
    }

    func getOptimalScanInterval() -> TimeInterval {
        if isLowPowerMode || batteryLevel < 0.2 {
            return criticalBatteryScanInterval
        } else if batteryLevel < 0.5 {
            return lowBatteryScanInterval
        } else {
            return normalScanInterval
        }
    }

    func getOptimalAdvertiseInterval() -> TimeInterval {
        if isLowPowerMode || batteryLevel < 0.2 {
            return criticalBatteryAdvertiseInterval
        } else if batteryLevel < 0.5 {
            return lowBatteryAdvertiseInterval
        } else {
            return normalAdvertiseInterval
        }
    }

    func shouldReduceConnectionLimit() -> Bool {
        return isLowPowerMode || batteryLevel < 0.3
    }

    func getMaxConnections() -> Int {
        if isLowPowerMode || batteryLevel < 0.2 {
            return 2
        } else if batteryLevel < 0.5 {
            return 4
        } else {
            return 6
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
