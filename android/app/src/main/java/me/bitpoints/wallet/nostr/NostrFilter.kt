package me.bitpoints.wallet.nostr

import com.google.gson.*
import java.lang.reflect.Type

/**
 * Nostr event filter for subscriptions
 * Compatible with iOS implementation
 */
data class NostrFilter(
    val ids: List<String>? = null,
    val authors: List<String>? = null,
    val kinds: List<Int>? = null,
    val since: Int? = null,
    val until: Int? = null,
    val limit: Int? = null,
    private val tagFilters: Map<String, List<String>>? = null
) {
    
    companion object {
        /**
         * Create filter for NIP-17 gift wraps
         */
        fun giftWrapsFor(pubkey: String, since: Long? = null): NostrFilter {
            return NostrFilter(
                kinds = listOf(NostrKind.GIFT_WRAP),
                since = since?.let { (it / 1000).toInt() },
                tagFilters = mapOf("p" to listOf(pubkey)),
                limit = 100
            )
        }
    }
    
    /**
     * Custom JSON serializer to handle tag filters properly
     */
    class FilterSerializer : JsonSerializer<NostrFilter> {
        override fun serialize(src: NostrFilter, typeOfSrc: Type, context: JsonSerializationContext): JsonElement {
            val jsonObject = JsonObject()
            
            // Standard fields
            src.ids?.let { jsonObject.add("ids", context.serialize(it)) }
            src.authors?.let { jsonObject.add("authors", context.serialize(it)) }
            src.kinds?.let { jsonObject.add("kinds", context.serialize(it)) }
            src.since?.let { jsonObject.addProperty("since", it) }
            src.until?.let { jsonObject.addProperty("until", it) }
            src.limit?.let { jsonObject.addProperty("limit", it) }
            
            // Tag filters with # prefix
            src.tagFilters?.forEach { (tag, values) ->
                jsonObject.add("#$tag", context.serialize(values))
            }
            
            return jsonObject
        }
    }
    
    /**
     * Check if an event matches this filter
     */
    fun matches(event: NostrEvent): Boolean {
        // Check IDs
        ids?.let { if (event.id !in it) return false }
        
        // Check authors
        authors?.let { if (event.pubkey !in it) return false }
        
        // Check kinds
        kinds?.let { if (event.kind !in it) return false }
        
        // Check since
        since?.let { if (event.createdAt < it) return false }
        
        // Check until
        until?.let { if (event.createdAt > it) return false }
        
        // Check tag filters
        tagFilters?.forEach { (tag, values) ->
            val matchingTag = event.tags.find { it.isNotEmpty() && it[0] == tag }
            if (matchingTag == null || matchingTag.size < 2 || matchingTag[1] !in values) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Get debug description for logging
     */
    fun getDebugDescription(): String {
        val parts = mutableListOf<String>()
        ids?.let { parts.add("ids=${it.size}") }
        authors?.let { parts.add("authors=${it.size}") }
        kinds?.let { parts.add("kinds=$it") }
        since?.let { parts.add("since=$it") }
        tagFilters?.let { parts.add("tags=${it.keys}") }
        return parts.joinToString(", ")
    }
}

