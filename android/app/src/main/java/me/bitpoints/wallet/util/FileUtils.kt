package me.bitpoints.wallet.util

import android.content.Context
import android.net.Uri
import me.bitpoints.wallet.model.BitchatFilePacket
import me.bitpoints.wallet.model.BitchatMessageType

/**
 * Stub implementation of FileUtils for cashu.me
 * File sharing features are not yet implemented
 */
object FileUtils {

    /**
     * Save incoming file to app storage
     * Stub: Returns a placeholder path
     */
    fun saveIncomingFile(context: Context, file: BitchatFilePacket): String {
        // TODO: Implement file saving when file sharing is needed
        return "file://stub/${file.fileName}"
    }

    /**
     * Determine message type from MIME type
     */
    fun messageTypeForMime(mimeType: String): BitchatMessageType {
        return when {
            mimeType.startsWith("image/") -> BitchatMessageType.Image
            mimeType.startsWith("video/") -> BitchatMessageType.File
            mimeType.startsWith("audio/") -> BitchatMessageType.Audio
            else -> BitchatMessageType.File
        }
    }

    /**
     * Copy file for sending via Bluetooth
     * Stub: Not implemented
     */
    fun copyFileForSending(context: Context, uri: Uri): String? {
        // TODO: Implement when file sharing is needed
        return null
    }

    /**
     * Get MIME type from file extension
     */
    fun getMimeTypeFromExtension(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "pdf" -> "application/pdf"
            "txt" -> "text/plain"
            "mp4" -> "video/mp4"
            "mp3" -> "audio/mpeg"
            else -> "application/octet-stream"
        }
    }

    /**
     * Format file size for display
     */
    fun formatFileSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            bytes < 1024 * 1024 * 1024 -> "${bytes / (1024 * 1024)} MB"
            else -> "${bytes / (1024 * 1024 * 1024)} GB"
        }
    }
}

