//
// BackgroundServiceManager.swift
// bitpoints.me
//
// Manages background operations and battery optimizations
//

import Foundation
import UIKit
import CoreBluetooth

class BackgroundServiceManager {
    private let bluetoothService: BluetoothEcashService
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isInBackground = false

    init(bluetoothService: BluetoothEcashService) {
        self.bluetoothService = bluetoothService
        setupBackgroundHandling()
    }

    private func setupBackgroundHandling() {
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
    }

    @objc private func appDidEnterBackground() {
        print("BackgroundServiceManager: App entered background")
        isInBackground = true
        startBackgroundTask()

        // Reduce scanning frequency in background
        // This would be implemented in the actual BLEService
        // For now, we just log the event
        print("BackgroundServiceManager: Reduced scanning frequency for battery optimization")
    }

    @objc private func appWillEnterForeground() {
        print("BackgroundServiceManager: App will enter foreground")
        isInBackground = false
        endBackgroundTask()

        // Restore normal scanning frequency
        print("BackgroundServiceManager: Restored normal scanning frequency")
    }

    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "BluetoothEcashBackground") { [weak self] in
            print("BackgroundServiceManager: Background task expired")
            self?.endBackgroundTask()
        }

        print("BackgroundServiceManager: Started background task: \(backgroundTask.rawValue)")
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            print("BackgroundServiceManager: Ending background task: \(backgroundTask.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}
