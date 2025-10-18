package me.bitpoints.wallet.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import java.util.*

/**
 * Delivery status for messages and ecash transfers
 * Unified status tracking for both BitchatMessage and EcashMessage
 */
sealed class DeliveryStatus : Parcelable {
    @Parcelize
    object Sending : DeliveryStatus()

    @Parcelize
    object Sent : DeliveryStatus()

    @Parcelize
    data class Delivered(val to: String, val at: Date) : DeliveryStatus()

    @Parcelize
    data class Read(val by: String, val at: Date) : DeliveryStatus()

    @Parcelize
    data class Claimed(val by: String, val at: Date) : DeliveryStatus()

    @Parcelize
    data class Failed(val reason: String) : DeliveryStatus()

    @Parcelize
    data class PartiallyDelivered(val reached: Int, val total: Int) : DeliveryStatus()

    fun getDisplayText(): String {
        return when (this) {
            is Sending -> "Sending..."
            is Sent -> "Sent"
            is Delivered -> "Delivered to ${this.to}"
            is Read -> "Read by ${this.by}"
            is Claimed -> "Claimed by ${this.by}"
            is Failed -> "Failed: ${this.reason}"
            is PartiallyDelivered -> "Delivered to ${this.reached}/${this.total}"
        }
    }
}

