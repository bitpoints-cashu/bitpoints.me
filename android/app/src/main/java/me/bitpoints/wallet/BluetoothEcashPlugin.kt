package me.bitpoints.wallet

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.getcapacitor.annotation.Permission
import com.getcapacitor.JSObject
import com.getcapacitor.JSArray
import me.bitpoints.wallet.model.EcashMessage
import me.bitpoints.wallet.mesh.PeerManager
import me.bitpoints.wallet.mesh.PeerInfo

/**
 * Capacitor plugin to expose Bluetooth ecash functionality to JavaScript
 *
 * This bridges the BluetoothEcashService (Kotlin) to the Vue/Quasar frontend (TypeScript)
 */
@CapacitorPlugin(
    name = "BluetoothEcash",
    permissions = [
        Permission(strings = [Manifest.permission.BLUETOOTH], alias = "bluetooth"),
        Permission(strings = [Manifest.permission.BLUETOOTH_ADMIN], alias = "bluetoothAdmin"),
        Permission(strings = [Manifest.permission.BLUETOOTH_ADVERTISE], alias = "bluetoothAdvertise"),
        Permission(strings = [Manifest.permission.BLUETOOTH_CONNECT], alias = "bluetoothConnect"),
        Permission(strings = [Manifest.permission.BLUETOOTH_SCAN], alias = "bluetoothScan"),
        Permission(strings = [Manifest.permission.POST_NOTIFICATIONS], alias = "notifications")
    ]
)
class BluetoothEcashPlugin : Plugin() {

    companion object {
        private const val TAG = "BluetoothEcashPlugin"
        private const val PERMISSION_REQUEST_CODE = 12345
    }

    private var bluetoothService: BluetoothEcashService? = null

    override fun load() {
        super.load()
        Log.d(TAG, "BluetoothEcashPlugin loaded")

        // Initialize service
        bluetoothService = BluetoothEcashService(context).apply {
            delegate = object : EcashDelegate {
                override fun onEcashReceived(message: EcashMessage) {
                    Log.d(TAG, "Ecash received: ${message.amount} ${message.unit}")
                    notifyListeners("ecashReceived", ecashMessageToJSObject(message))
                }

                override fun onPeerDiscovered(peer: PeerInfo) {
                    Log.d(TAG, "Peer discovered: ${peer.id}")
                    notifyListeners("peerDiscovered", peerToJSObject(peer))
                }

                override fun onPeerLost(peerID: String) {
                    Log.d(TAG, "Peer lost: $peerID")
                    val ret = JSObject()
                    ret.put("peerID", peerID)
                    notifyListeners("peerLost", ret)
                }

                override fun onTokenSent(messageId: String) {
                    Log.d(TAG, "Token sent: $messageId")
                    val ret = JSObject()
                    ret.put("messageId", messageId)
                    notifyListeners("tokenSent", ret)
                }

                override fun onTokenSendFailed(messageId: String, reason: String) {
                    Log.e(TAG, "Token send failed: $messageId - $reason")
                    val ret = JSObject()
                    ret.put("messageId", messageId)
                    ret.put("reason", reason)
                    notifyListeners("tokenSendFailed", ret)
                }

                override fun onTokenDelivered(messageId: String, peerID: String) {
                    Log.d(TAG, "Token delivered: $messageId to $peerID")
                    val ret = JSObject()
                    ret.put("messageId", messageId)
                    ret.put("peerID", peerID)
                    notifyListeners("tokenDelivered", ret)
                }

                override fun onFavoriteNotificationReceived(fromPeerID: String, npub: String, isFavorite: Boolean) {
                    Log.d(TAG, "Favorite notification received: peerID=$fromPeerID, npub=${npub.take(16)}..., isFavorite=$isFavorite")
                    val ret = JSObject()
                    ret.put("peerID", fromPeerID)
                    ret.put("npub", npub)
                    ret.put("isFavorite", isFavorite)
                    notifyListeners("favoriteNotificationReceived", ret)
                }

                override fun onFavoriteRequestReceived(fromPeerID: String, nickname: String, npub: String) {
                    Log.i(TAG, "📬 [PLUGIN] Favorite request received: peerID=$fromPeerID, nickname=$nickname, npub=${npub.take(16)}...")
                    val ret = JSObject()
                    ret.put("peerID", fromPeerID)
                    ret.put("nickname", nickname)
                    ret.put("npub", npub)
                    Log.i(TAG, "📬 [PLUGIN] Notifying listeners for favoriteRequestReceived")
                    notifyListeners("favoriteRequestReceived", ret)
                    Log.i(TAG, "📬 [PLUGIN] Listeners notified successfully")
                }

                override fun onFavoriteAcceptedReceived(fromPeerID: String, npub: String) {
                    Log.d(TAG, "Favorite accepted received: peerID=$fromPeerID, npub=${npub.take(16)}...")
                    val ret = JSObject()
                    ret.put("peerID", fromPeerID)
                    ret.put("npub", npub)
                    notifyListeners("favoriteAcceptedReceived", ret)
                }
            }
        }
    }

    /**
     * Start the Bluetooth mesh service
     */
    @PluginMethod
    fun startService(call: PluginCall) {
        try {
            // Check permissions first
            if (!hasRequiredPermissions()) {
                call.reject("Bluetooth permissions not granted")
                return
            }

            bluetoothService?.start()
            call.resolve()
            Log.i(TAG, "Bluetooth service started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start service", e)
            call.reject("Failed to start service: ${e.message}")
        }
    }

    /**
     * Stop the Bluetooth mesh service
     */
    @PluginMethod
    fun stopService(call: PluginCall) {
        try {
            bluetoothService?.stop()
            call.resolve()
            Log.i(TAG, "Bluetooth service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop service", e)
            call.reject("Failed to stop service: ${e.message}")
        }
    }

    /**
     * Set the Bluetooth nickname (how you appear to nearby peers)
     *
     * @param nickname Display name for Bluetooth mesh (3-32 characters)
     */
    @PluginMethod
    fun setNickname(call: PluginCall) {
        try {
            val nickname = call.getString("nickname")
            if (nickname == null || nickname.isEmpty()) {
                call.reject("Nickname is required")
                return
            }

            bluetoothService?.setNickname(nickname)

            val ret = JSObject()
            ret.put("nickname", nickname)
            call.resolve(ret)
            Log.i(TAG, "Nickname set to: $nickname")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set nickname", e)
            call.reject("Failed to set nickname: ${e.message}")
        }
    }

    /**
     * Get the current Bluetooth nickname
     */
    @PluginMethod
    fun getNickname(call: PluginCall) {
        try {
            val nickname = bluetoothService?.getNickname() ?: "Bitpoints User"

            val ret = JSObject()
            ret.put("nickname", nickname)
            call.resolve(ret)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get nickname", e)
            call.reject("Failed to get nickname: ${e.message}")
        }
    }

    /**
     * Check if Bluetooth is enabled on the device
     */
    @PluginMethod
    fun isBluetoothEnabled(call: PluginCall) {
        try {
            val bluetoothManager = context.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
            val bluetoothAdapter = bluetoothManager?.adapter
            val isEnabled = bluetoothAdapter?.isEnabled == true

            val ret = JSObject()
            ret.put("enabled", isEnabled)
            call.resolve(ret)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check Bluetooth status", e)
            call.reject("Failed to check Bluetooth status: ${e.message}")
        }
    }

    /**
     * Prompt user to enable Bluetooth
     */
    @PluginMethod
    fun requestBluetoothEnable(call: PluginCall) {
        try {
            val bluetoothManager = context.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
            val bluetoothAdapter = bluetoothManager?.adapter

            if (bluetoothAdapter == null) {
                call.reject("Bluetooth not supported on this device")
                return
            }

            if (bluetoothAdapter.isEnabled) {
                val ret = JSObject()
                ret.put("enabled", true)
                call.resolve(ret)
                return
            }

            // Request to enable Bluetooth
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ requires BLUETOOTH_CONNECT permission
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
                    != PackageManager.PERMISSION_GRANTED) {
                    call.reject("BLUETOOTH_CONNECT permission not granted")
                    return
                }
            }

            val enableBtIntent = android.content.Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE)
            enableBtIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(enableBtIntent)

            val ret = JSObject()
            ret.put("requested", true)
            call.resolve(ret)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request Bluetooth enable", e)
            call.reject("Failed to request Bluetooth enable: ${e.message}")
        }
    }

    /**
     * Send ecash token to nearby peer(s)
     *
     * @param token Base64-encoded Cashu token
     * @param amount Amount in base units
     * @param unit Currency unit ("sat" or "point")
     * @param mint Mint URL
     * @param peerID Optional peer ID (null for broadcast)
     * @param memo Optional memo
     * @param senderNpub Sender's Nostr npub
     */
    @PluginMethod
    fun sendToken(call: PluginCall) {
        Log.d(TAG, "🚀 sendToken called from frontend")
        try {
            val token = call.getString("token") ?: run {
                Log.e(TAG, "❌ Token is required but not provided")
                call.reject("Token is required")
                return
            }
            Log.d(TAG, "📦 Token received: ${token.take(50)}...")
            val amount = call.getInt("amount") ?: run {
                call.reject("Amount is required")
                return
            }
            val unit = call.getString("unit") ?: "sat"
            val mint = call.getString("mint") ?: run {
                call.reject("Mint URL is required")
                return
            }
            val peerID = call.getString("peerID")  // Optional
            val memo = call.getString("memo")
            val senderNpub = call.getString("senderNpub") ?: run {
                call.reject("Sender npub is required")
                return
            }

            val messageId = bluetoothService?.sendEcashToken(
                token, amount, unit, mint, peerID, memo, senderNpub
            ) ?: run {
                call.reject("Service not initialized")
                return
            }

            val ret = JSObject()
            ret.put("messageId", messageId)
            call.resolve(ret)

            Log.d(TAG, "Initiated ecash send: $messageId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send token", e)
            call.reject("Failed to send token: ${e.message}")
        }
    }

    /**
     * Send plain text message to a specific peer (for favorite notifications, etc)
     *
     * @param peerID Peer ID to send to
     * @param message Text message content
     */
    @PluginMethod
    fun sendTextMessage(call: PluginCall) {
        try {
            val peerID = call.getString("peerID") ?: run {
                call.reject("Peer ID is required")
                return
            }
            val message = call.getString("message") ?: run {
                call.reject("Message is required")
                return
            }

            // Send via mesh service
            bluetoothService?.sendTextMessageToPeer(peerID, message)

            call.resolve()
            Log.d(TAG, "Sent text message to $peerID: ${message.take(30)}...")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send text message", e)
            call.reject("Failed to send text message: ${e.message}")
        }
    }

    /**
     * Get list of currently available peers
     */
    @PluginMethod
    fun getAvailablePeers(call: PluginCall) {
        try {
            val peers = bluetoothService?.getAvailablePeers() ?: emptyList()

            val peersArray = JSArray()
            peers.forEach { peer ->
                peersArray.put(peerToJSObject(peer))
            }

            val ret = JSObject()
            ret.put("peers", peersArray)
            call.resolve(ret)

            Log.d(TAG, "Returned ${peers.size} available peers")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get peers", e)
            call.reject("Failed to get peers: ${e.message}")
        }
    }

    /**
     * Get unclaimed tokens received via Bluetooth
     */
    @PluginMethod
    fun getUnclaimedTokens(call: PluginCall) {
        try {
            val tokens = bluetoothService?.getUnclaimedTokens() ?: emptyList()

            val tokensArray = JSArray()
            tokens.forEach { token ->
                tokensArray.put(ecashMessageToJSObject(token))
            }

            val ret = JSObject()
            ret.put("tokens", tokensArray)
            call.resolve(ret)

            Log.d(TAG, "Returned ${tokens.size} unclaimed tokens")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get unclaimed tokens", e)
            call.reject("Failed to get unclaimed tokens: ${e.message}")
        }
    }

    /**
     * Mark a token as claimed after successful redemption
     */
    @PluginMethod
    fun markTokenClaimed(call: PluginCall) {
        try {
            val messageId = call.getString("messageId") ?: run {
                call.reject("Message ID is required")
                return
            }

            bluetoothService?.markTokenClaimed(messageId)
            call.resolve()

            Log.d(TAG, "Marked token as claimed: $messageId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to mark token claimed", e)
            call.reject("Failed to mark token claimed: ${e.message}")
        }
    }

    /**
     * Request Bluetooth permissions
     */
    @PluginMethod
    override fun requestPermissions(call: PluginCall) {
        if (hasRequiredPermissions()) {
            val ret = JSObject()
            ret.put("granted", true)
            call.resolve(ret)
            return
        }

        // Save call for permission result callback
        savedCall = call

        // Request permissions
        val permissions = getRequiredPermissions()
        ActivityCompat.requestPermissions(activity, permissions, PERMISSION_REQUEST_CODE)
    }

    /**
     * Check if all required permissions are granted
     */
    override fun hasRequiredPermissions(): Boolean {
        val permissions = getRequiredPermissions()
        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * Get list of required permissions based on Android version
     */
    private fun getRequiredPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ (SDK 31+): No location required with neverForLocation flag
            arrayOf(
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.POST_NOTIFICATIONS
            )
        } else {
            // Android 11 and below: Location required for BLE scanning
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }
    }

    /**
     * Convert PeerInfo to JSObject for JavaScript
     */
    private fun peerToJSObject(peer: PeerInfo): JSObject {
        val obj = JSObject()
        obj.put("peerID", peer.id)  // 'id' in Kotlin, 'peerID' in JS
        obj.put("nickname", peer.nickname)
        obj.put("lastSeen", peer.lastSeen)
        obj.put("isDirect", peer.isDirectConnection)  // 'isDirectConnection' in Kotlin
        obj.put("nostrNpub", "")  // Not stored in PeerInfo yet
        obj.put("isConnected", peer.isConnected)
        return obj
    }

    /**
     * Convert EcashMessage to JSObject for JavaScript
     */
    private fun ecashMessageToJSObject(message: EcashMessage): JSObject {
        val obj = JSObject()
        obj.put("id", message.id)
        obj.put("sender", message.sender)
        obj.put("senderPeerID", message.senderPeerID)
        obj.put("timestamp", message.timestamp.time)
        obj.put("amount", message.amount)
        obj.put("unit", message.unit)
        obj.put("cashuToken", message.cashuToken)
        obj.put("mint", message.mint)
        obj.put("memo", message.memo ?: "")
        obj.put("claimed", message.claimed)
        obj.put("deliveryStatus", message.deliveryStatus.getDisplayText())
        return obj
    }

    private var savedCall: PluginCall? = null

    override fun handleOnDestroy() {
        bluetoothService?.destroy()
        super.handleOnDestroy()
    }

    /**
     * Start always-on mode (foreground service)
     */
    @PluginMethod
    fun startAlwaysOnMode(call: PluginCall) {
        try {
            val intent = Intent(context, AlwaysOnService::class.java).apply {
                action = AlwaysOnService.ACTION_START_SERVICE
            }

            context.startForegroundService(intent)

            val ret = JSObject()
            ret.put("success", true)
            ret.put("message", "Always-on mode started")
            call.resolve(ret)

            Log.d(TAG, "Always-on mode started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start always-on mode", e)
            call.reject("Failed to start always-on mode: ${e.message}")
        }
    }

    /**
     * Stop always-on mode
     */
    @PluginMethod
    fun stopAlwaysOnMode(call: PluginCall) {
        try {
            val intent = Intent(context, AlwaysOnService::class.java).apply {
                action = AlwaysOnService.ACTION_STOP_SERVICE
            }

            context.startService(intent)

            val ret = JSObject()
            ret.put("success", true)
            ret.put("message", "Always-on mode stopped")
            call.resolve(ret)

            Log.d(TAG, "Always-on mode stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop always-on mode", e)
            call.reject("Failed to stop always-on mode: ${e.message}")
        }
    }

    /**
     * Check if always-on mode is active
     */
    @PluginMethod
    fun isAlwaysOnActive(call: PluginCall) {
        try {
            val ret = JSObject()
            ret.put("isActive", AlwaysOnService.isServiceRunning)
            call.resolve(ret)

            Log.d(TAG, "Always-on status checked: ${AlwaysOnService.isServiceRunning}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check always-on status", e)
            call.reject("Failed to check always-on status: ${e.message}")
        }
    }

    /**
     * Request battery optimization exemption
     */
    @PluginMethod
    fun requestBatteryOptimizationExemption(call: PluginCall) {
        try {
            // This needs to be called from the main activity context
            // We'll notify the main activity to show the dialog
            val intent = Intent("me.bitpoints.wallet.REQUEST_BATTERY_OPTIMIZATION")
            context.sendBroadcast(intent)

            val ret = JSObject()
            ret.put("success", true)
            ret.put("message", "Battery optimization dialog requested")
            call.resolve(ret)

            Log.d(TAG, "Battery optimization exemption requested")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request battery optimization exemption", e)
            call.reject("Failed to request battery optimization exemption: ${e.message}")
        }
    }
}

