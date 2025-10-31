package me.bitpoints.wallet.services

import android.content.Context
import android.util.Log
import me.bitpoints.wallet.mesh.BluetoothMeshService
import me.bitpoints.wallet.nostr.NostrTransport

/**
 * Routes messages between BLE mesh and Nostr transports, matching iOS behavior.
 */
class MessageRouter private constructor(
    private val context: Context,
    private val mesh: BluetoothMeshService,
    private val nostr: NostrTransport
) {
    companion object {
        private const val TAG = "MessageRouter"
        @Volatile private var INSTANCE: MessageRouter? = null
        fun tryGetInstance(): MessageRouter? = INSTANCE
        fun getInstance(context: Context, mesh: BluetoothMeshService): MessageRouter {
            return INSTANCE ?: synchronized(this) {
                val nostr = NostrTransport.getInstance(context)
                INSTANCE?.also {
                    // Update mesh reference if needed and keep senderPeerID in sync
                    it.nostr.senderPeerID = mesh.myPeerID
                    return it
                }
                MessageRouter(context.applicationContext, mesh, nostr).also { instance ->
                    instance.nostr.senderPeerID = mesh.myPeerID
                    // Register for favorites changes to flush outbox
                    try {
                        me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared.addListener(instance.favoriteListener)
                    } catch (_: Exception) {}
                    INSTANCE = instance
                }
            }
        }
    }

    // Outbox: peerID -> queued (content, nickname, messageID)
    private val outbox = mutableMapOf<String, MutableList<Triple<String, String, String>>>()

    // Listener for favorites changes to flush outbox when npub mapping appears/changes
    private val favoriteListener = object: me.bitpoints.wallet.favorites.FavoritesChangeListener {

        override fun onFavoriteChanged(noiseKeyHex: String) {
            flushOutboxFor(noiseKeyHex)
            // Also try 16-hex short id commonly used in UI if any client used that
            val shortId = noiseKeyHex.take(16)
            flushOutboxFor(shortId)
        }
        override fun onAllCleared() {
            // Nothing special; leave queued items until routing becomes possible
        }
    }

    fun sendPrivate(content: String, toPeerID: String, recipientNickname: String, messageID: String) {
        val hasMesh = mesh.getPeerInfo(toPeerID)?.isConnected == true
        val hasEstablished = mesh.hasEstablishedSession(toPeerID)
        if (hasMesh && hasEstablished) {
            Log.d(TAG, "Routing PM via mesh to ${toPeerID} msg_id=${messageID.take(8)}…")
            mesh.sendPrivateMessageViaMesh(content, toPeerID, recipientNickname, messageID)
        } else if (canSendViaNostr(toPeerID)) {
            Log.d(TAG, "Routing PM via Nostr to ${toPeerID.take(32)}… msg_id=${messageID.take(8)}…")
            nostr.sendPrivateMessage(content, toPeerID, recipientNickname, messageID)
        } else {
            Log.d(TAG, "Queued PM for ${toPeerID} (no mesh, no Nostr mapping) msg_id=${messageID.take(8)}…")
            val q = outbox.getOrPut(toPeerID) { mutableListOf() }
            q.add(Triple(content, recipientNickname, messageID))
            Log.d(TAG, "Initiating noise handshake after queueing PM for ${toPeerID.take(8)}…")
            mesh.initiateNoiseHandshake(toPeerID)
        }
    }

    fun sendReadReceipt(messageID: String, toPeerID: String) {
        val nickname = mesh.getPeerNicknames()[toPeerID] ?: mesh.myPeerID
        if ((mesh.getPeerInfo(toPeerID)?.isConnected == true) && mesh.hasEstablishedSession(toPeerID)) {
            Log.d(TAG, "Routing READ via mesh to ${toPeerID.take(8)}… id=${messageID.take(8)}…")
            mesh.sendReadReceipt(messageID, toPeerID, nickname)
        } else {
            Log.d(TAG, "Routing READ via Nostr to ${toPeerID.take(8)}… id=${messageID.take(8)}…")
            nostr.sendReadReceipt(messageID, toPeerID)
        }
    }

    fun sendDeliveryAck(messageID: String, toPeerID: String) {
        // Mesh delivery ACKs are sent by the receiver automatically.
        // Only route via Nostr when mesh path isn't available
        if (!((mesh.getPeerInfo(toPeerID)?.isConnected == true) && mesh.hasEstablishedSession(toPeerID))) {
            nostr.sendDeliveryAck(messageID, toPeerID)
        }
    }

    fun sendFavoriteNotification(toPeerID: String, isFavorite: Boolean) {
        val myNpub = try { me.bitpoints.wallet.nostr.NostrIdentityBridge.getCurrentNostrIdentity(context)?.npub } catch (_: Exception) { null }
        val content = if (isFavorite) "[FAVORITED]:${myNpub ?: ""}" else "[UNFAVORITED]:${myNpub ?: ""}"
        val nickname = mesh.getPeerNicknames()[toPeerID] ?: toPeerID
        val messageID = java.util.UUID.randomUUID().toString()
        
        // Use the same routing logic as sendPrivate - this ensures proper queueing and session handling
        Log.d(TAG, "📨 sendFavoriteNotification: peer=$toPeerID, isFavorite=$isFavorite")
        sendPrivate(content, toPeerID, nickname, messageID)
    }

    // Flush any queued messages for a specific peerID
    fun flushOutboxFor(peerID: String) {
        val queued = outbox[peerID] ?: return
        if (queued.isEmpty()) return
        Log.d(TAG, "Flushing outbox for ${peerID.take(8)}… count=${queued.size}")
        val iterator = queued.iterator()
        while (iterator.hasNext()) {
            val (content, nickname, messageID) = iterator.next()
            var hasMesh = mesh.getPeerInfo(peerID)?.isConnected == true && mesh.hasEstablishedSession(peerID)
            // If this is a noiseHex key, see if there is a connected mesh peer for this identity
            if (!hasMesh && peerID.length == 64 && peerID.matches(Regex("^[0-9a-fA-F]+$"))) {
                val meshPeer = resolveMeshPeerForNoiseHex(peerID)
                if (meshPeer != null && mesh.getPeerInfo(meshPeer)?.isConnected == true && mesh.hasEstablishedSession(meshPeer)) {
                    mesh.sendPrivateMessageViaMesh(content, meshPeer, nickname, messageID)
                    iterator.remove()
                    continue
                }
            }
            val canNostr = canSendViaNostr(peerID)
            if (hasMesh) {
                mesh.sendPrivateMessageViaMesh(content, peerID, nickname, messageID)
                iterator.remove()
            } else if (canNostr) {
                nostr.sendPrivateMessage(content, peerID, nickname, messageID)
                iterator.remove()
            }
        }
        if (queued.isEmpty()) {
            outbox.remove(peerID)
        }
    }

    // Flush everything (rarely used)
    fun flushAllOutbox() {
        outbox.keys.toList().forEach { flushOutboxFor(it) }
    }

    private fun canSendViaNostr(peerID: String): Boolean {
        return try {
            // Full Noise key hex
            if (peerID.length == 64 && peerID.matches(Regex("^[0-9a-fA-F]+$"))) {
                val noiseKey = hexToBytes(peerID)
                val fav = me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared.getFavoriteStatus(noiseKey)
                fav?.isMutual == true && fav.peerNostrPublicKey != null
            } else if (peerID.length == 16 && peerID.matches(Regex("^[0-9a-fA-F]+$"))) {
                // Ephemeral 16-hex mesh ID: resolve via prefix match in favorites
                val fav = me.bitpoints.wallet.favorites.FavoritesPersistenceService.shared.getFavoriteStatus(peerID)
                fav?.isMutual == true && fav.peerNostrPublicKey != null
            } else {
                false
            }
        } catch (_: Exception) { false }
    }

    private fun hexToBytes(hex: String): ByteArray {
        val clean = if (hex.length % 2 == 0) hex else "0$hex"
        return clean.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }

    private fun resolveMeshPeerForNoiseHex(noiseHex: String): String? {
        return try {
            mesh.getPeerNicknames().keys.firstOrNull { pid ->
                val info = mesh.getPeerInfo(pid)
                val keyHex = info?.noisePublicKey?.joinToString("") { b -> "%02x".format(b) }
                keyHex != null && keyHex.equals(noiseHex, ignoreCase = true)
            }
        } catch (_: Exception) { null }
    }

    // Called when mesh peer list changes; attempt to flush any matching outbox entries
    fun onPeersUpdated(peers: List<String>) {
        peers.forEach { pid ->
            flushOutboxFor(pid)
            val noiseHex = try {
                mesh.getPeerInfo(pid)?.noisePublicKey?.joinToString("") { b -> "%02x".format(b) }
            } catch (_: Exception) { null }
            noiseHex?.let { flushOutboxFor(it) }
        }
    }

    // Called when a Noise session becomes established; flush both the mesh peerID and its noiseHex alias
    fun onSessionEstablished(peerID: String) {
        flushOutboxFor(peerID)
        val noiseHex = try {
            mesh.getPeerInfo(peerID)?.noisePublicKey?.joinToString("") { b -> "%02x".format(b) }
        } catch (_: Exception) { null }
        noiseHex?.let { flushOutboxFor(it) }
    }
}

