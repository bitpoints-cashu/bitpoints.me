package me.bitpoints.wallet

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import me.bitpoints.wallet.mesh.BluetoothMeshService
import me.bitpoints.wallet.mesh.BluetoothMeshDelegate
import me.bitpoints.wallet.model.BitchatMessage
import me.bitpoints.wallet.model.EcashMessage
import me.bitpoints.wallet.R

/**
 * Always-On Foreground Service for Kids' Devices
 *
 * Keeps Bitpoints Bluetooth mesh active 24/7 for devices without consistent internet.
 * Shows persistent notification and prevents Android from killing the app.
 */
class AlwaysOnService : Service(), BluetoothMeshDelegate {

    companion object {
        private const val TAG = "AlwaysOnService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "bitpoints_always_on"
        private const val CHANNEL_NAME = "Bitpoints Always-On Mode"

        // Actions for service control
        const val ACTION_START_SERVICE = "me.bitpoints.wallet.START_ALWAYS_ON"
        const val ACTION_STOP_SERVICE = "me.bitpoints.wallet.STOP_ALWAYS_ON"

        // Service state
        var isServiceRunning = false
            private set
    }

    private var bluetoothMeshService: BluetoothMeshService? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var isBluetoothActive = false
    private var peerCount = 0
    private var lastActivityTime = System.currentTimeMillis()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AlwaysOnService created")
        createNotificationChannel()
        acquireWakeLock()
        initializeBluetoothMesh()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "AlwaysOnService onStartCommand: ${intent?.action}")

        when (intent?.action) {
            ACTION_START_SERVICE -> {
                startForegroundService()
                return START_STICKY // Restart if killed by system
            }
            ACTION_STOP_SERVICE -> {
                stopForegroundService()
                return START_NOT_STICKY
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "AlwaysOnService destroyed")
        cleanup()
        super.onDestroy()
    }

    /**
     * Start the foreground service with persistent notification
     */
    private fun startForegroundService() {
        if (isServiceRunning) {
            Log.w(TAG, "Service already running")
            return
        }

        Log.d(TAG, "Starting foreground service")
        isServiceRunning = true

        // Create and show notification
        val notification = createNotification()

        // Start foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Start Bluetooth mesh
        startBluetoothMesh()
    }

    /**
     * Stop the foreground service
     */
    private fun stopForegroundService() {
        Log.d(TAG, "Stopping foreground service")
        isServiceRunning = false
        stopBluetoothMesh()
        stopForeground(true)
        stopSelf()
    }

    /**
     * Create notification channel for Android O+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Bitpoints Bluetooth mesh active for offline token transfers"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create the persistent notification
     */
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Build status text
        val statusText = when {
            !isBluetoothActive -> "Starting Bluetooth mesh..."
            peerCount == 0 -> "Bluetooth active - No peers nearby"
            else -> "Bluetooth active - $peerCount peer(s) connected"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bitpoints Mesh Active")
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Use system icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    /**
     * Update the notification with current status
     */
    private fun updateNotification() {
        if (!isServiceRunning) return

        val notification = createNotification()
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    /**
     * Acquire wake lock to keep CPU active
     */
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Bitpoints::AlwaysOnWakeLock"
        ).apply {
            acquire(10 * 60 * 60 * 1000L /*10 hours*/)
            Log.d(TAG, "Wake lock acquired")
        }
    }

    /**
     * Initialize Bluetooth mesh service
     */
    private fun initializeBluetoothMesh() {
        try {
            bluetoothMeshService = BluetoothMeshService(this)
            bluetoothMeshService?.delegate = this
            Log.d(TAG, "Bluetooth mesh service initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Bluetooth mesh", e)
        }
    }

    /**
     * Start Bluetooth mesh networking
     */
    private fun startBluetoothMesh() {
        try {
            bluetoothMeshService?.startServices()
            isBluetoothActive = true
            Log.d(TAG, "Bluetooth mesh started")
            updateNotification()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Bluetooth mesh", e)
            isBluetoothActive = false
            updateNotification()
        }
    }

    /**
     * Stop Bluetooth mesh networking
     */
    private fun stopBluetoothMesh() {
        try {
            bluetoothMeshService?.stopServices()
            isBluetoothActive = false
            peerCount = 0
            Log.d(TAG, "Bluetooth mesh stopped")
            updateNotification()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop Bluetooth mesh", e)
        }
    }

    /**
     * Cleanup resources
     */
    private fun cleanup() {
        stopBluetoothMesh()

        wakeLock?.let { wl ->
            if (wl.isHeld) {
                wl.release()
                Log.d(TAG, "Wake lock released")
            }
        }

        isServiceRunning = false
    }

    /**
     * Request battery optimization exemption
     */
    fun requestBatteryOptimizationExemption() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            Log.d(TAG, "Requested battery optimization exemption")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request battery optimization exemption", e)
        }
    }

    // BluetoothMeshDelegate implementations
    override fun didReceiveMessage(message: BitchatMessage) {
        lastActivityTime = System.currentTimeMillis()
        Log.d(TAG, "Message received from ${message.senderPeerID}")
    }

    override fun didUpdatePeerList(peers: List<String>) {
        lastActivityTime = System.currentTimeMillis()
        peerCount = peers.size
        Log.d(TAG, "Peer list updated: $peerCount peers")
        updateNotification()
    }

    override fun didReceiveChannelLeave(channel: String, fromPeer: String) {
        lastActivityTime = System.currentTimeMillis()
        Log.d(TAG, "Channel leave: $channel from $fromPeer")
    }

    override fun didReceiveDeliveryAck(messageID: String, recipientPeerID: String) {
        lastActivityTime = System.currentTimeMillis()
        Log.d(TAG, "Message delivered: $messageID to $recipientPeerID")
    }

    override fun didReceiveReadReceipt(messageID: String, recipientPeerID: String) {
        lastActivityTime = System.currentTimeMillis()
        Log.d(TAG, "Read receipt: $messageID from $recipientPeerID")
    }

    override fun decryptChannelMessage(encryptedContent: ByteArray, channel: String): String? {
        // Not implemented for always-on service
        return null
    }

    override fun getNickname(): String? {
        // Read user's configured nickname from shared preferences
        // This matches the frontend's 'bluetooth-nickname' localStorage key
        val prefs = getSharedPreferences("VueUseLocalStorage", Context.MODE_PRIVATE)
        return prefs.getString("bluetooth-nickname", "Bitpoints User") ?: "Bitpoints User"
    }

    override fun isFavorite(peerID: String): Boolean {
        // Not implemented for always-on service
        return false
    }
}

