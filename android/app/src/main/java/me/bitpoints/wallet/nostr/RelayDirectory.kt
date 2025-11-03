package me.bitpoints.wallet.nostr

import android.util.Log
import me.bitpoints.wallet.net.OkHttpProvider

/**
 * Simplified RelayDirectory for Bitpoints
 * For now, just uses default relays. Full geohash-based relay selection can be added later if needed.
 */
object RelayDirectory {
    
    private const val TAG = "RelayDirectory"
    
    /**
     * Return up to nRelays closest relay URLs to the geohash center.
     * For now, just returns default relays up to nRelays.
     */
    fun closestRelaysForGeohash(geohash: String, nRelays: Int): List<String> {
        // For basic DM functionality, just return default relays
        // Full geohash-based selection can be implemented later
        val defaultRelays = listOf(
            "wss://relay.damus.io",
            "wss://relay.primal.net",
            "wss://offchain.pub",
            "wss://nostr21.com"
        )
        return defaultRelays.take(nRelays)
    }
}

