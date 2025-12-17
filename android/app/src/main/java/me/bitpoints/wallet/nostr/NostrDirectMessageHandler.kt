package me.bitpoints.wallet.nostr

import android.content.Context
import android.util.Log
import me.bitpoints.wallet.model.BitchatMessage
import me.bitpoints.wallet.model.NoisePayload
import me.bitpoints.wallet.model.NoisePayloadType
import me.bitpoints.wallet.model.PrivateMessagePacket
import me.bitpoints.wallet.protocol.BitchatPacket
import me.bitpoints.wallet.protocol.MessageType
import kotlinx.coroutines.*
import java.util.*

/**
 * Handles incoming Nostr direct messages and integrates with Bitpoints message infrastructure
 * Simplified version for Bitpoints (no geohash-specific features)
 */
class NostrDirectMessageHandler(
    private val context: Context,
    private val onMessageReceived: (BitchatMessage) -> Unit,
    private val onDeliveryAckReceived: ((messageID: String, peerID: String) -> Unit)? = null,
    private val onReadReceiptReceived: ((messageID: String, peerID: String) -> Unit)? = null
) {
    companion object { 
        private const val TAG = "NostrDirectMessageHandler" 
    }

    // Simple event deduplication
    private val processedIds = ArrayDeque<String>()
    private val seen = HashSet<String>()
    private val max = 2000

    private fun dedupe(id: String): Boolean {
        if (seen.contains(id)) return true
        seen.add(id)
        processedIds.addLast(id)
        if (processedIds.size > max) {
            val old = processedIds.removeFirst()
            seen.remove(old)
        }
        return false
    }

    fun onGiftWrap(giftWrap: NostrEvent, identity: NostrIdentity) {
        CoroutineScope(Dispatchers.Default).launch {
            try {
                if (dedupe(giftWrap.id)) return@launch

                val messageAge = System.currentTimeMillis() / 1000 - giftWrap.createdAt
                if (messageAge > 173700) return@launch // 48 hours + 15 mins

                val decryptResult = NostrProtocol.decryptPrivateMessage(giftWrap, identity)
                if (decryptResult == null) {
                    Log.w(TAG, "Failed to decrypt Nostr message")
                    return@launch
                }

                val (content, senderPubkey, rumorTimestamp) = decryptResult

                if (!content.startsWith("bitchat1:")) return@launch

                val base64Content = content.removePrefix("bitchat1:")
                val packetData = base64URLDecode(base64Content) ?: return@launch
                val packet = BitchatPacket.fromBinaryData(packetData) ?: return@launch

                if (packet.type != MessageType.NOISE_ENCRYPTED.value) return@launch

                val noisePayload = NoisePayload.decode(packet.payload) ?: return@launch
                val messageTimestamp = Date(giftWrap.createdAt * 1000L)
                
                // Use senderPubkey to create a stable conversation key
                // For mesh peers, we'll use the 16-hex prefix; for Nostr-only, use nostr_ prefix
                val convKey = if (packet.recipientID != null && packet.recipientID!!.isNotEmpty()) {
                    // Try to resolve recipientID to mesh peerID
                    val recipientIDHex = packet.recipientID!!.joinToString("") { "%02x".format(it) }
                    // Look up if this maps to an existing peer
                    recipientIDHex
                } else {
                    // Nostr-only conversation
                    "nostr_${senderPubkey.take(16)}"
                }

                // Try to get nickname from favorites or use default
                val senderNickname = try {
                    val relationship = me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared
                        .getFavoriteStatus(senderPubkey.hexToByteArray())
                    relationship?.peerNickname ?: "Nostr User ${senderPubkey.take(8)}"
                } catch (e: Exception) {
                    "Nostr User ${senderPubkey.take(8)}"
                }

                processNoisePayload(noisePayload, convKey, senderNickname, messageTimestamp, senderPubkey, identity)

            } catch (e: Exception) {
                Log.e(TAG, "onGiftWrap error: ${e.message}")
            }
        }
    }

    private suspend fun processNoisePayload(
        payload: NoisePayload,
        convKey: String,
        senderNickname: String,
        timestamp: Date,
        senderPubkey: String,
        recipientIdentity: NostrIdentity
    ) {
        when (payload.type) {
            NoisePayloadType.PRIVATE_MESSAGE -> {
                val pm = PrivateMessagePacket.decode(payload.data) ?: return

                // Handle favorite/unfavorite notifications
                val pmContent = pm.content
                if (pmContent.startsWith("[FAVORITED]") || pmContent.startsWith("[UNFAVORITED]")) {
                    handleFavoriteNotificationFromNostr(pmContent, senderPubkey, convKey)
                    return
                }

                val message = BitchatMessage(
                    id = pm.messageID,
                    sender = senderNickname,
                    content = pm.content,
                    timestamp = timestamp,
                    isRelay = false,
                    isPrivate = true,
                    recipientNickname = null, // Will be filled by delegate if needed
                    senderPeerID = convKey
                )

                withContext(Dispatchers.Main) {
                    onMessageReceived(message)
                }

                // Send delivery ACK
                val nostrTransport = NostrTransport.getInstance(context)
                nostrTransport.sendDeliveryAck(pm.messageID, convKey)
            }
            NoisePayloadType.DELIVERED -> {
                val messageId = String(payload.data, Charsets.UTF_8)
                withContext(Dispatchers.Main) {
                    onDeliveryAckReceived?.invoke(messageId, convKey)
                }
            }
            NoisePayloadType.READ_RECEIPT -> {
                val messageId = String(payload.data, Charsets.UTF_8)
                withContext(Dispatchers.Main) {
                    onReadReceiptReceived?.invoke(messageId, convKey)
                }
            }
            NoisePayloadType.FILE_TRANSFER -> {
                val file = me.bitpoints.wallet.model.BitchatFilePacket.decode(payload.data)
                if (file != null) {
                    val uniqueMsgId = UUID.randomUUID().toString().uppercase()
                    val savedPath = me.bitpoints.wallet.util.FileUtils.saveIncomingFile(context, file)
                    val message = BitchatMessage(
                        id = uniqueMsgId,
                        sender = senderNickname,
                        content = savedPath,
                        type = me.bitpoints.wallet.util.FileUtils.messageTypeForMime(file.mimeType),
                        timestamp = timestamp,
                        isRelay = false,
                        isPrivate = true,
                        recipientNickname = null,
                        senderPeerID = convKey
                    )
                    Log.d(TAG, "📄 Saved Nostr encrypted incoming file to $savedPath (msgId=$uniqueMsgId)")
                    withContext(Dispatchers.Main) {
                        onMessageReceived(message)
                    }
                    
                    // Send delivery ACK
                    val nostrTransport = NostrTransport.getInstance(context)
                    nostrTransport.sendDeliveryAck(uniqueMsgId, convKey)
                } else {
                    Log.w(TAG, "⚠️ Failed to decode Nostr file transfer from $convKey")
                }
            }
        }
    }

    private fun handleFavoriteNotificationFromNostr(content: String, senderPubkey: String, convKey: String) {
        try {
            val isFavorite = content.startsWith("[FAVORITED]")
            val npub = content.substringAfter(":", "").trim().takeIf { it.startsWith("npub1") }

            // Convert senderPubkey hex to ByteArray for favorites lookup
            val senderPubkeyBytes = senderPubkey.hexToByteArray()
            
            // Update mutual favorite status
            me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared.updatePeerFavoritedUs(senderPubkeyBytes, isFavorite)
            
            if (npub != null) {
                // Update Nostr pubkey mapping
                me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared.updateNostrPublicKey(senderPubkeyBytes, npub)
                
                // Also try to index by convKey if it looks like a peerID
                if (convKey.length == 16 && convKey.matches(Regex("^[0-9a-f]+$"))) {
                    me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared.updateNostrPublicKeyForPeerID(convKey, npub)
                }
            }

            Log.d(TAG, "Processed favorite notification from Nostr: $isFavorite, npub=${npub?.take(16)}...")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle favorite notification from Nostr: ${e.message}")
        }
    }

    private fun base64URLDecode(input: String): ByteArray? {
        return try {
            val padded = input.replace("-", "+")
                .replace("_", "/")
                .let { str ->
                    val padding = (4 - str.length % 4) % 4
                    str + "=".repeat(padding)
                }
            android.util.Base64.decode(padded, android.util.Base64.DEFAULT)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decode base64url: ${e.message}")
            null
        }
    }
}

