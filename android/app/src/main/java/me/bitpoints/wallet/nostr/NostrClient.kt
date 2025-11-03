package me.bitpoints.wallet.nostr

import android.content.Context
import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import kotlinx.coroutines.*

/**
 * High-level Nostr client that manages identity, connections, and messaging
 * Provides a simple API for the rest of the application
 */
class NostrClient private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "NostrClient"
        
        @Volatile
        private var INSTANCE: NostrClient? = null
        
        fun getInstance(context: Context): NostrClient {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: NostrClient(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    // Core components
    private val relayManager = NostrRelayManager.shared
    private var currentIdentity: NostrIdentity? = null
    
    // Client state
    private val _isInitialized = MutableLiveData<Boolean>()
    val isInitialized: LiveData<Boolean> = _isInitialized
    
    private val _currentNpub = MutableLiveData<String>()
    val currentNpub: LiveData<String> = _currentNpub
    
    // Message processing
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    init {
        Log.d(TAG, "Initializing Nostr client")
    }
    
    /**
     * Initialize the Nostr client with identity and relay connections
     */
    fun initialize() {
        scope.launch {
            try {
                // Load or create identity
                currentIdentity = NostrIdentityBridge.getCurrentNostrIdentity(context)
                
                if (currentIdentity != null) {
                    _currentNpub.postValue(currentIdentity!!.npub)
                    Log.i(TAG, "✅ Nostr identity loaded: ${currentIdentity!!.getShortNpub()}")
                    
                    // Connect to relays
                    relayManager.connect()
                    
                    _isInitialized.postValue(true)
                    Log.i(TAG, "✅ Nostr client initialized successfully")
                } else {
                    Log.e(TAG, "❌ Failed to load/create Nostr identity")
                    _isInitialized.postValue(false)
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to initialize Nostr client: ${e.message}")
                _isInitialized.postValue(false)
            }
        }
    }
    
    /**
     * Shutdown the client and disconnect from relays
     */
    fun shutdown() {
        Log.d(TAG, "Shutting down Nostr client")
        relayManager.disconnect()
        _isInitialized.postValue(false)
    }
    
    /**
     * Send a private message using NIP-17
     */
    fun sendPrivateMessage(
        content: String,
        recipientNpub: String,
        onSuccess: (() -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        val identity = currentIdentity
        if (identity == null) {
            onError?.invoke("Nostr client not initialized")
            return
        }
        
        scope.launch {
            try {
                // Decode recipient npub to hex pubkey
                val (hrp, pubkeyBytes) = Bech32.decode(recipientNpub)
                if (hrp != "npub") {
                    onError?.invoke("Invalid npub format")
                    return@launch
                }
                
                val recipientPubkeyHex = pubkeyBytes.toHexString()
                
                // Create and send gift wraps (receiver and sender copies)
                val giftWraps = NostrProtocol.createPrivateMessage(
                    content = content,
                    recipientPubkey = recipientPubkeyHex,
                    senderIdentity = identity
                )
                
                // Track and send all gift wraps
                giftWraps.forEach { wrap ->
                    NostrRelayManager.registerPendingGiftWrap(wrap.id)
                    relayManager.sendEvent(wrap)
                }
                
                Log.i(TAG, "📤 Sent private message to ${recipientNpub.take(16)}...")
                onSuccess?.invoke()
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to send private message: ${e.message}")
                onError?.invoke("Failed to send message: ${e.message}")
            }
        }
    }
    
    /**
     * Subscribe to private messages for current identity
     */
    fun subscribeToPrivateMessages(
        messageHandler: NostrDirectMessageHandler
    ) {
        val identity = currentIdentity
        if (identity == null) {
            Log.e(TAG, "Cannot subscribe to private messages: client not initialized")
            return
        }
        
        val filter = NostrFilter.giftWrapsFor(
            pubkey = identity.publicKeyHex,
            since = System.currentTimeMillis() - 172800000L // Last 48 hours (align with NIP-17 randomization)
        )
        
        relayManager.subscribe(filter, "private-messages", { giftWrap ->
            scope.launch {
                messageHandler.onGiftWrap(giftWrap, identity)
            }
        })
        
        Log.i(TAG, "🔑 Subscribed to private messages for: ${identity.getShortNpub()}")
    }
    
    /**
     * Get current identity information
     */
    fun getCurrentIdentity(): NostrIdentity? = currentIdentity
    
    /**
     * Get relay connection status
     */
    val relayConnectionStatus: LiveData<Boolean> = relayManager.isConnected
    
    /**
     * Get relay information
     */
    val relayInfo: LiveData<List<NostrRelayManager.Relay>> = relayManager.relays
    
}

