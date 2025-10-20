package me.bitpoints.wear

import android.graphics.Bitmap
import android.graphics.Color
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.common.BitMatrix
import android.util.Log

/**
 * QR Code generator utility for Wear OS
 */
object QRCodeGenerator {
    private const val TAG = "QRCodeGenerator"

    /**
     * Generate a QR code bitmap from a string
     */
    fun generateQRCode(text: String, width: Int = 400, height: Int = 400): Bitmap? {
        return try {
            val writer = QRCodeWriter()
            val hints = hashMapOf<EncodeHintType, Any>().apply {
                put(EncodeHintType.CHARACTER_SET, "UTF-8")
                put(EncodeHintType.MARGIN, 1)
            }

            val bitMatrix: BitMatrix = writer.encode(text, BarcodeFormat.QR_CODE, width, height, hints)

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)

            for (x in 0 until width) {
                for (y in 0 until height) {
                    bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
                }
            }

            Log.d(TAG, "QR code generated successfully for: $text")
            bitmap
        } catch (e: Exception) {
            Log.e(TAG, "Error generating QR code", e)
            null
        }
    }

    /**
     * Generate a Lightning QR code with proper formatting (like main app)
     */
    fun generateLightningQRCode(bolt11: String, width: Int = 400, height: Int = 400): Bitmap? {
        val lightningUri = "lightning:${bolt11.uppercase()}"
        Log.d(TAG, "Generating Lightning QR code for: $lightningUri")
        return generateQRCode(lightningUri, width, height)
    }

    /**
     * Generate a Cashu token QR code
     */
    fun generateCashuQRCode(token: String, width: Int = 400, height: Int = 400): Bitmap? {
        Log.d(TAG, "Generating Cashu QR code for token")
        return generateQRCode(token, width, height)
    }
}
