package me.bitpoints.wallet.ui.debug

/**
 * Stub implementation of DebugPreferenceManager for cashu.me
 * Provides default configuration values
 */
object DebugPreferenceManager {

    fun getSeenPacketCapacity(default: Int): Int = default

    fun getGcsMaxFilterBytes(default: Int): Int = default

    fun getGcsFprPercent(default: Double): Double = default
}

