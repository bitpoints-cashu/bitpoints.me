package me.bitpoints.wallet.ui.debug

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Stub implementation of DebugSettingsManager for cashu.me
 * Provides default values for debugging features without UI
 */
class DebugSettingsManager private constructor() {

    val gattClientEnabled = MutableStateFlow(true)
    val gattServerEnabled = MutableStateFlow(true)
    val packetRelayEnabled = MutableStateFlow(true)

    // Scan result tracking (stub - no-op in production)
    fun addScanResult(result: DebugScanResult) {
        // No-op: We don't have debug UI
    }

    fun addConnectionEvent(event: String) {
        // No-op: We don't have debug UI
    }

    fun logIncomingPacket(peerID: String, nickname: String?, messageType: String, routeDevice: String?) {
        // No-op: We don't have debug UI
    }

    fun logPeerConnection(peerID: String, nickname: String, deviceAddress: String, isInbound: Boolean) {
        // No-op: We don't have debug UI
    }

    fun logPeerDisconnection(peerID: String, nickname: String, deviceAddress: String) {
        // No-op: We don't have debug UI
    }

    fun logPacketRelayDetailed(
        packetType: String,
        senderPeerID: String,
        senderNickname: String?,
        fromPeerID: String?,
        fromNickname: String?,
        fromDeviceAddress: String?,
        toPeerID: String?,
        toNickname: String?,
        toDeviceAddress: String?,
        ttl: Int? = null,
        isRelay: Boolean
    ) {
        // No-op: We don't have debug UI
    }

    companion object {
        @Volatile
        private var instance: DebugSettingsManager? = null

        fun getInstance(): DebugSettingsManager {
            return instance ?: synchronized(this) {
                instance ?: DebugSettingsManager().also { instance = it }
            }
        }
    }
}

data class DebugScanResult(
    val deviceName: String?,
    val deviceAddress: String,
    val rssi: Int,
    val peerID: String?
)

