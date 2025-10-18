package me.bitpoints.wallet.mesh

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat

/**
 * Handles all Bluetooth permission checking logic
 */
class BluetoothPermissionManager(private val context: Context) {

    /**
     * Check if all required Bluetooth permissions are granted
     */
    fun hasBluetoothPermissions(): Boolean {
        val permissions = mutableListOf<String>()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12+ (SDK 31+): Use new Bluetooth permissions
            // Location not required when using BLUETOOTH_SCAN with neverForLocation flag
            permissions.addAll(listOf(
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            ))
        } else {
            // Android 11 and below: Use legacy Bluetooth permissions
            // Location IS required for BLE scanning
            permissions.addAll(listOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION
            ))
        }

        return permissions.all {
            ActivityCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }
}
