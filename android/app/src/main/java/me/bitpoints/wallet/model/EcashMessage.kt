package me.bitpoints.wallet.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.*

/**
 * EcashMessage - Represents a Cashu ecash token transfer over Bluetooth mesh
 *
 * This extends the BitchatMessage concept but specifically for ecash token transfers.
 * Tokens are transmitted as base64-encoded Cashu tokens with metadata.
 */
@Parcelize
data class EcashMessage(
    val id: String = UUID.randomUUID().toString().uppercase(),
    val sender: String,  // Nostr npub
    val senderPeerID: String,  // BLE peer ID (16-char hex)
    val timestamp: Date,
    val amount: Int,  // Amount in base unit (sats or points)
    val unit: String,  // "sat" or "point"
    val cashuToken: String,  // base64 encoded Cashu token
    val mint: String,  // mint URL
    val memo: String? = null,
    val claimed: Boolean = false,
    val deliveryStatus: DeliveryStatus = DeliveryStatus.Sending,
    val recipientNpub: String? = null  // For private transfers
) : Parcelable {

    /**
     * Convert ecash message to binary payload for Bluetooth transmission
     *
     * Binary format:
     * - Flags: 1 byte (memo, claimed, recipient)
     * - Timestamp: 8 bytes (milliseconds since epoch, big-endian)
     * - Amount: 4 bytes (big-endian int)
     * - Unit length: 1 byte + unit data
     * - ID length: 1 byte + ID data
     * - Sender length: 1 byte + sender data (npub)
     * - SenderPeerID length: 1 byte + peerID data
     * - Cashu token length: 2 bytes + token data
     * - Mint URL length: 1 byte + URL data
     * [Optional] Memo length: 1 byte + memo data
     * [Optional] Claimed flag: already in flags byte
     * [Optional] Recipient npub length: 1 byte + npub data
     */
    fun toBinaryPayload(): ByteArray? {
        try {
            val buffer = ByteBuffer.allocate(16384).apply { order(ByteOrder.BIG_ENDIAN) }

            // Flags byte
            var flags: UByte = 0u
            if (memo != null) flags = flags or 0x01u
            if (claimed) flags = flags or 0x02u
            if (recipientNpub != null) flags = flags or 0x04u
            buffer.put(flags.toByte())

            // Timestamp (8 bytes)
            buffer.putLong(timestamp.time)

            // Amount (4 bytes)
            buffer.putInt(amount)

            // Unit
            val unitBytes = unit.toByteArray(Charsets.UTF_8)
            buffer.put(minOf(unitBytes.size, 255).toByte())
            buffer.put(unitBytes.take(255).toByteArray())

            // ID
            val idBytes = id.toByteArray(Charsets.UTF_8)
            buffer.put(minOf(idBytes.size, 255).toByte())
            buffer.put(idBytes.take(255).toByteArray())

            // Sender (npub)
            val senderBytes = sender.toByteArray(Charsets.UTF_8)
            buffer.put(minOf(senderBytes.size, 255).toByte())
            buffer.put(senderBytes.take(255).toByteArray())

            // SenderPeerID
            val peerIDBytes = senderPeerID.toByteArray(Charsets.UTF_8)
            buffer.put(minOf(peerIDBytes.size, 255).toByte())
            buffer.put(peerIDBytes.take(255).toByteArray())

            // Cashu token (can be large, use 2 bytes for length)
            val tokenBytes = cashuToken.toByteArray(Charsets.UTF_8)
            val tokenLength = minOf(tokenBytes.size, 65535)
            buffer.putShort(tokenLength.toShort())
            buffer.put(tokenBytes.take(tokenLength).toByteArray())

            // Mint URL
            val mintBytes = mint.toByteArray(Charsets.UTF_8)
            buffer.put(minOf(mintBytes.size, 255).toByte())
            buffer.put(mintBytes.take(255).toByteArray())

            // Optional fields
            memo?.let { memoText ->
                val memoBytes = memoText.toByteArray(Charsets.UTF_8)
                buffer.put(minOf(memoBytes.size, 255).toByte())
                buffer.put(memoBytes.take(255).toByteArray())
            }

            recipientNpub?.let { recipient ->
                val recipBytes = recipient.toByteArray(Charsets.UTF_8)
                buffer.put(minOf(recipBytes.size, 255).toByte())
                buffer.put(recipBytes.take(255).toByteArray())
            }

            val result = ByteArray(buffer.position())
            buffer.rewind()
            buffer.get(result)
            return result

        } catch (e: Exception) {
            return null
        }
    }

    companion object {
        /**
         * Parse ecash message from binary payload received over Bluetooth
         */
        fun fromBinaryPayload(data: ByteArray): EcashMessage? {
            try {
                if (data.size < 20) return null  // Minimum size check

                val buffer = ByteBuffer.wrap(data).apply { order(ByteOrder.BIG_ENDIAN) }

                // Flags
                val flags = buffer.get().toUByte()
                val hasMemo = (flags and 0x01u) != 0u.toUByte()
                val claimed = (flags and 0x02u) != 0u.toUByte()
                val hasRecipient = (flags and 0x04u) != 0u.toUByte()

                // Timestamp
                val timestampMillis = buffer.getLong()
                val timestamp = Date(timestampMillis)

                // Amount
                val amount = buffer.getInt()

                // Unit
                val unitLength = buffer.get().toInt() and 0xFF
                if (buffer.remaining() < unitLength) return null
                val unitBytes = ByteArray(unitLength)
                buffer.get(unitBytes)
                val unit = String(unitBytes, Charsets.UTF_8)

                // ID
                val idLength = buffer.get().toInt() and 0xFF
                if (buffer.remaining() < idLength) return null
                val idBytes = ByteArray(idLength)
                buffer.get(idBytes)
                val id = String(idBytes, Charsets.UTF_8)

                // Sender
                val senderLength = buffer.get().toInt() and 0xFF
                if (buffer.remaining() < senderLength) return null
                val senderBytes = ByteArray(senderLength)
                buffer.get(senderBytes)
                val sender = String(senderBytes, Charsets.UTF_8)

                // SenderPeerID
                val peerIDLength = buffer.get().toInt() and 0xFF
                if (buffer.remaining() < peerIDLength) return null
                val peerIDBytes = ByteArray(peerIDLength)
                buffer.get(peerIDBytes)
                val senderPeerID = String(peerIDBytes, Charsets.UTF_8)

                // Cashu token
                val tokenLength = buffer.getShort().toInt() and 0xFFFF
                if (buffer.remaining() < tokenLength) return null
                val tokenBytes = ByteArray(tokenLength)
                buffer.get(tokenBytes)
                val cashuToken = String(tokenBytes, Charsets.UTF_8)

                // Mint URL
                val mintLength = buffer.get().toInt() and 0xFF
                if (buffer.remaining() < mintLength) return null
                val mintBytes = ByteArray(mintLength)
                buffer.get(mintBytes)
                val mint = String(mintBytes, Charsets.UTF_8)

                // Optional memo
                val memo = if (hasMemo && buffer.hasRemaining()) {
                    val memoLength = buffer.get().toInt() and 0xFF
                    if (buffer.remaining() >= memoLength) {
                        val memoBytes = ByteArray(memoLength)
                        buffer.get(memoBytes)
                        String(memoBytes, Charsets.UTF_8)
                    } else null
                } else null

                // Optional recipient
                val recipientNpub = if (hasRecipient && buffer.hasRemaining()) {
                    val recipLength = buffer.get().toInt() and 0xFF
                    if (buffer.remaining() >= recipLength) {
                        val recipBytes = ByteArray(recipLength)
                        buffer.get(recipBytes)
                        String(recipBytes, Charsets.UTF_8)
                    } else null
                } else null

                return EcashMessage(
                    id = id,
                    sender = sender,
                    senderPeerID = senderPeerID,
                    timestamp = timestamp,
                    amount = amount,
                    unit = unit,
                    cashuToken = cashuToken,
                    mint = mint,
                    memo = memo,
                    claimed = claimed,
                    recipientNpub = recipientNpub
                )

            } catch (e: Exception) {
                return null
            }
        }
    }
}


