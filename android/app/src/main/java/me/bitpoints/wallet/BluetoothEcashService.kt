package me.bitpoints.wallet

import android.content.Context
import android.util.Log
import me.bitpoints.wallet.mesh.BluetoothMeshService
import me.bitpoints.wallet.mesh.BluetoothMeshDelegate
import me.bitpoints.wallet.mesh.PeerInfo
import me.bitpoints.wallet.model.EcashMessage
import me.bitpoints.wallet.model.DeliveryStatus
import me.bitpoints.wallet.protocol.BitchatPacket
import me.bitpoints.wallet.protocol.MessageType
import me.bitpoints.wallet.model.RoutedPacket
import android.bluetooth.BluetoothDevice
import kotlinx.coroutines.*
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * BluetoothEcashService - High-level service for sending/receiving ecash tokens via Bluetooth mesh
 *
 * This wraps BluetoothMeshService and provides ecash-specific functionality:
 * - Send tokens to nearby peers or broadcast
 * - Receive tokens and store for claiming
 * - Track peer discovery and connection status
 * - Manage delivery status and notifications
 */
class BluetoothEcashService(private val context: Context) {

    companion object {
        private const val TAG = "BluetoothEcashService"
        private const val ECASH_MESSAGE_TYPE: UByte = 0xE1u  // Custom message type for ecash
    }

    private val meshService = BluetoothMeshService(context)
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Ecash-specific state
    private val pendingTokens = ConcurrentHashMap<String, EcashMessage>()
    private val receivedTokens = ConcurrentHashMap<String, EcashMessage>()

    // User configurable nickname
    private var myNickname: String = "Bitpoints User"

    // Delegate for callbacks to UI
    var delegate: EcashDelegate? = null

    init {
        setupMeshDelegate()
    }

    /**
     * Wire up the mesh service delegate to handle incoming packets
     */
    private fun setupMeshDelegate() {
        meshService.delegate = object : me.bitpoints.wallet.mesh.BluetoothMeshDelegate {
            override fun didReceiveMessage(message: me.bitpoints.wallet.model.BitchatMessage) {
                // Check if message content contains a Cashu token or favorite notification
                val content = message.content.trim()
                Log.d(TAG, "Received TEXT message: ${content.take(50)}...")

                // Handle favorite notifications (matches bitchat implementation)
                if (content.startsWith("[FAVORITE_REQUEST]:") ||
                    content.startsWith("[FAVORITE_ACCEPTED]:") ||
                    content.startsWith("[UNFAVORITED]:")) {
                    Log.i(TAG, "🔔 FAVORITE NOTIFICATION DETECTED: ${content.substring(0, 30)}...")
                    handleFavoriteNotification(content, message.senderPeerID ?: "unknown", message.sender)
                    return  // Don't process as regular message
                }

                // Detect Cashu token (starts with "cashuA" or "cashuB")
                if (content.startsWith("cashuA") || content.startsWith("cashuB")) {
                    Log.i(TAG, "🎉 Detected Cashu token in TEXT message!")

                    // Parse token and optional metadata
                    val lines = content.split("\n")
                    val tokenString = lines[0]  // First line is always the token

                    // Extract metadata if present (from memo format)
                    var amount = 0
                    var unit = "sat"
                    var parsedMemo: String? = null

                    for (line in lines) {
                        when {
                            line.startsWith("Amount: ") -> {
                                val parts = line.substringAfter("Amount: ").split(" ")
                                amount = parts[0].toIntOrNull() ?: 0
                                unit = parts.getOrNull(1) ?: "sat"
                            }
                            line.startsWith("Memo: ") -> {
                                parsedMemo = line.substringAfter("Memo: ")
                            }
                        }
                    }

                    // Create EcashMessage
                    val ecashMessage = EcashMessage(
                        id = UUID.randomUUID().toString(),
                        sender = message.sender,
                        senderPeerID = message.senderPeerID ?: "unknown",
                        timestamp = message.timestamp,
                        amount = amount,
                        unit = unit,
                        cashuToken = tokenString,
                        mint = "",  // Will be determined when claiming
                        memo = parsedMemo,
                        claimed = false,
                        deliveryStatus = DeliveryStatus.Delivered(message.senderPeerID ?: "unknown", Date()),
                        recipientNpub = null
                    )

                    // Store and notify
                    receivedTokens[ecashMessage.id] = ecashMessage
                    delegate?.onEcashReceived(ecashMessage)

                    Log.i(TAG, "✅ Stored ecash token: ${amount} ${unit} from ${message.sender.take(16)}...")
                }
            }

            override fun didUpdatePeerList(peers: List<String>) {
                Log.d(TAG, "Peer list updated: ${peers.size} peers")
                // Get full peer info and notify delegate
                peers.forEach { peerID ->
                    meshService.getAllPeers().find { it.id == peerID }?.let { peer ->
                        delegate?.onPeerDiscovered(peer)
                    }
                }
            }

            override fun didReceiveChannelLeave(channel: String, fromPeer: String) {
                // Not used for ecash - channels are for group chat
            }

            override fun didReceiveDeliveryAck(messageID: String, recipientPeerID: String) {
                Log.d(TAG, "Delivery ack for message $messageID from $recipientPeerID")
                delegate?.onTokenDelivered(messageID, recipientPeerID)
            }

            override fun didReceiveReadReceipt(messageID: String, recipientPeerID: String) {
                Log.d(TAG, "Read receipt for message $messageID from $recipientPeerID")
            }

            override fun decryptChannelMessage(encryptedContent: ByteArray, channel: String): String? {
                // Not used for ecash
                return null
            }

            override fun getNickname(): String? {
                return myNickname
            }

            override fun isFavorite(peerID: String): Boolean {
                // All peers are treated equally for ecash
                return false
            }

            override fun didReceiveCustomPacket(packet: BitchatPacket, fromPeerID: String?, relayAddress: String?) {
                // Check if this is an ecash packet (type 0xE1)
                if (packet.type == ECASH_MESSAGE_TYPE) {
                    Log.i(TAG, "Received ecash packet from ${fromPeerID ?: "broadcast"}")
                    handleIncomingEcashPacket(packet, fromPeerID, relayAddress)
                } else {
                    Log.d(TAG, "Received unknown custom packet type: 0x${packet.type.toString(16)}")
                }
            }
        }
    }

    /**
     * Start the Bluetooth mesh service
     * Begins advertising and scanning for nearby peers
     */
    fun start() {
        Log.i(TAG, "Starting Bluetooth ecash service")
        meshService.startServices()
    }

    /**
     * Stop the Bluetooth mesh service
     */
    fun stop() {
        Log.i(TAG, "Stopping Bluetooth ecash service")
        meshService.stopServices()
    }

    /**
     * Set the Bluetooth nickname (how you appear to nearby peers)
     * Requires service restart to take effect
     *
     * @param nickname Display name for Bluetooth mesh (3-32 characters)
     */
    fun setNickname(nickname: String) {
        if (nickname.length < 3 || nickname.length > 32) {
            Log.w(TAG, "Nickname must be 3-32 characters, ignoring")
            return
        }

        val oldNickname = myNickname
        myNickname = nickname
        Log.i(TAG, "Bluetooth nickname updated: '$oldNickname' -> '$myNickname'")

        // Note: Service must be restarted for nickname change to take effect in announcements
    }

    /**
     * Get the current Bluetooth nickname
     */
    fun getNickname(): String {
        return myNickname
    }

    /**
     * Send ecash token to specific peer(s) via Bluetooth mesh
     *
     * @param token Base64-encoded Cashu token
     * @param amount Amount in base units
     * @param unit Currency unit ("sat" or "point")
     * @param mint Mint URL
     * @param peerID Target peer ID (null for broadcast)
     * @param memo Optional memo text
     * @param senderNpub Sender's Nostr npub
     * @return Message ID for tracking delivery
     */
    fun sendEcashToken(
        token: String,
        amount: Int,
        unit: String,
        mint: String,
        peerID: String?,
        memo: String?,
        senderNpub: String
    ): String {
        val messageId = UUID.randomUUID().toString()

        // SIMPLIFIED: Send as TEXT message (Cashu tokens are bearer tokens - no additional encryption needed)
        // Format: Just the token, or token with metadata if memo provided
        val messageText = if (memo != null) {
            "$token\n---\nMemo: $memo\nAmount: $amount $unit\nFrom: ${senderNpub.take(16)}..."
        } else {
            token  // Just the raw Cashu token for maximum simplicity
        }

        Log.d(TAG, "Sending ecash token as TEXT message: ${amount} ${unit}, token length: ${token.length}")

        serviceScope.launch {
            try {
                if (peerID != null) {
                    // Send to specific peer
                    Log.d(TAG, "Sending TEXT to specific peer: $peerID")
                    meshService.sendMessageToPeer(peerID, messageText)
                } else {
                    // Broadcast to all nearby peers
                    Log.d(TAG, "Broadcasting TEXT to all nearby peers")
                    meshService.sendMessage(messageText)
                }

                // Track as pending
                val message = EcashMessage(
                    id = messageId,
                    sender = senderNpub,
                    senderPeerID = meshService.myPeerID,
                    timestamp = Date(),
                    amount = amount,
                    unit = unit,
                    cashuToken = token,
                    mint = mint,
                    memo = memo,
                    claimed = false,
                    deliveryStatus = DeliveryStatus.Sent,
                    recipientNpub = peerID
                )
                pendingTokens[messageId] = message
                delegate?.onTokenSent(messageId)

                Log.i(TAG, "Ecash token sent as TEXT: $messageId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send ecash token", e)
                delegate?.onTokenSendFailed(messageId, e.message ?: "Unknown error")
            }
        }

        return messageId
    }

    /**
     * Broadcast ecash token to all nearby peers (for kids without specific contacts)
     */
    fun broadcastEcashToken(
        token: String,
        amount: Int,
        unit: String,
        mint: String,
        memo: String?,
        senderNpub: String
    ): String {
        return sendEcashToken(token, amount, unit, mint, null, memo, senderNpub)
    }

    /**
     * Get list of currently available peers
     */
    fun getAvailablePeers(): List<PeerInfo> {
        return meshService.getAllPeers()
    }

    /**
     * Get unclaimed tokens received via Bluetooth
     */
    fun getUnclaimedTokens(): List<EcashMessage> {
        return receivedTokens.values.filter { !it.claimed }.toList()
    }

    /**
     * Mark a token as claimed after successful redemption with mint
     */
    fun markTokenClaimed(messageId: String) {
        receivedTokens[messageId]?.let { message ->
            val updated = message.copy(
                claimed = true,
                deliveryStatus = DeliveryStatus.Claimed(meshService.myPeerID, Date())
            )
            receivedTokens[messageId] = updated
            Log.d(TAG, "Token ${messageId} marked as claimed")
        }
    }

    /**
     * Handle incoming ecash packet from mesh network
     */
    private fun handleIncomingEcashPacket(
        packet: BitchatPacket,
        fromPeerID: String?,
        relayAddress: String?
    ) {
        serviceScope.launch {
            try {
                val message = EcashMessage.fromBinaryPayload(packet.payload)
                if (message == null) {
                    Log.e(TAG, "Failed to parse ecash message from packet")
                    return@launch
                }

                Log.i(TAG, "Received ecash token: ${message.amount} ${message.unit} from ${message.sender}")

                // Check if this is for us or if we should relay it
                val isForUs = message.recipientNpub == null ||
                              message.recipientNpub == getCurrentUserNpub()

                if (isForUs) {
                    // Store the token for claiming
                    receivedTokens[message.id] = message

                    // Notify delegate
                    delegate?.onEcashReceived(message)

                    // If from a peer, update delivery status
                    fromPeerID?.let { peerID ->
                        val updatedMessage = message.copy(
                            deliveryStatus = DeliveryStatus.Delivered(peerID, Date())
                        )
                        receivedTokens[message.id] = updatedMessage
                        delegate?.onTokenDelivered(message.id, peerID)
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error handling incoming ecash packet", e)
            }
        }
    }

    /**
     * Get current user's Nostr npub
     * TODO: Integrate with cashu.me's Nostr identity management
     */
    private fun getCurrentUserNpub(): String? {
        // TODO: Get from SharedPreferences or cashu.me's nostr store
        return null
    }

    /**
     * Cleanup resources
     */
    fun destroy() {
        serviceScope.cancel()
        meshService.stopServices()
    }

    /**
     * Convert hex string to byte array
     */
    private fun hexToBytes(hex: String): ByteArray {
        val clean = if (hex.length % 2 == 0) hex else "0$hex"
        val out = ByteArray(clean.length / 2)
        var i = 0
        while (i < clean.length) {
            val b = clean.substring(i, i + 2).toInt(16).toByte()
            out[i / 2] = b
            i += 2
        }
        return out
    }

    /**
     * Send plain text message to a specific peer (for favorite notifications)
     */
    fun sendTextMessageToPeer(peerID: String, message: String) {
        Log.d(TAG, "Sending text message to $peerID: ${message.take(30)}...")
        meshService.sendMessageToPeer(peerID, message)
    }

    /**
     * Handle favorite/unfavorite notifications (matches bitchat implementation)
     * Format: "[FAVORITED]:npub1..." or "[UNFAVORITED]:npub1..."
     */
    private fun handleFavoriteNotification(content: String, fromPeerID: String, nickname: String?) {
        try {
            val npub = content.substringAfter(":", "").trim()

            // Validate npub format
            if (!npub.startsWith("npub1")) {
                Log.w(TAG, "Invalid npub format in favorite notification")
                return
            }

            when {
                content.startsWith("[FAVORITE_REQUEST]:") -> {
                    Log.i(TAG, "📬 Processing FAVORITE_REQUEST from $fromPeerID (${nickname ?: "Unknown"}) with npub: ${npub.take(16)}...")
                    delegate?.onFavoriteRequestReceived(fromPeerID, nickname ?: "Unknown", npub)
                    Log.i(TAG, "📬 Delegate notified for FAVORITE_REQUEST")
                }
                content.startsWith("[FAVORITE_ACCEPTED]:") -> {
                    Log.i(TAG, "✅ Processing FAVORITE_ACCEPTED from $fromPeerID with npub: ${npub.take(16)}...")
                    delegate?.onFavoriteAcceptedReceived(fromPeerID, npub)
                    Log.i(TAG, "✅ Delegate notified for FAVORITE_ACCEPTED")
                }
                content.startsWith("[UNFAVORITED]:") -> {
                    Log.i(TAG, "💔 Processing UNFAVORITE notification from $fromPeerID with npub: ${npub.take(16)}...")
                    delegate?.onFavoriteNotificationReceived(fromPeerID, npub, false)
                    Log.i(TAG, "💔 Delegate notified for UNFAVORITE")
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle favorite notification", e)
        }
    }
}

/**
 * Delegate interface for ecash-specific callbacks
 */
interface EcashDelegate {
    /**
     * Called when an ecash token is received via Bluetooth
     */
    fun onEcashReceived(message: EcashMessage)

    /**
     * Called when a new peer is discovered nearby
     */
    fun onPeerDiscovered(peer: PeerInfo)

    /**
     * Called when a peer disconnects
     */
    fun onPeerLost(peerID: String)

    /**
     * Called when a token is successfully sent
     */
    fun onTokenSent(messageId: String)

    /**
     * Called when a token send fails
     */
    fun onTokenSendFailed(messageId: String, reason: String)

    /**
     * Called when a token is delivered to a peer
     */
    fun onTokenDelivered(messageId: String, peerID: String)

    /**
     * Called when a favorite/unfavorite notification is received
     */
    fun onFavoriteNotificationReceived(fromPeerID: String, npub: String, isFavorite: Boolean)

    /**
     * Called when a favorite request is received
     */
    fun onFavoriteRequestReceived(fromPeerID: String, nickname: String, npub: String)

    /**
     * Called when a favorite acceptance is received
     */
    fun onFavoriteAcceptedReceived(fromPeerID: String, npub: String)
}

