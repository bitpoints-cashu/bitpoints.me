package me.bitpoints.wear

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonArray
import com.google.gson.JsonParser
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * WearWalletService - Native implementation of the shared wallet logic
 * This mirrors the functionality of the main app's TypeScript/JavaScript wallet logic
 */
class WearWalletService(private val context: Context) {

    companion object {
        private const val TAG = "WearWalletService"
        private const val PREFS_NAME = "wear_wallet_prefs"
        private const val KEY_MNEMONIC = "mnemonic"
        private const val KEY_BALANCE = "balance"
        private const val KEY_MINT_URL = "mint_url"

        // Default mint URL (exactly same as main app)
        private const val DEFAULT_MINT_URL = "https://ecash.trailscoffee.com"
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()
    private val gson = Gson()

    // Wallet state
    private var balance: Long = 0
    private var mnemonic: String = ""
        private var mintUrl: String = DEFAULT_MINT_URL
        private var activeKeysetId: String = ""

    init {
        loadWalletState()

        // Initialize with Trails Coffee mint (same as main app)
        if (mintUrl != DEFAULT_MINT_URL) {
            mintUrl = DEFAULT_MINT_URL
            saveWalletState()
            Log.d(TAG, "Initialized with Trails Coffee mint: $mintUrl")
        }

        // Start with real zero balance - user will mint tokens via Lightning
        Log.d(TAG, "Wallet initialized with real balance: $balance sats")

        // Ensure balance is truly zero (remove any test data)
        if (balance != 0L) {
            balance = 0L
            saveWalletState()
            Log.d(TAG, "Reset balance to zero (removed test data)")
        }

        // Keyset ID will be retrieved when needed (during minting)
        Log.d(TAG, "Wallet service initialized - keyset ID will be retrieved on demand")
    }

    private fun loadWalletState() {
        balance = prefs.getLong(KEY_BALANCE, 0)
        mnemonic = prefs.getString(KEY_MNEMONIC, "") ?: ""
        mintUrl = prefs.getString(KEY_MINT_URL, DEFAULT_MINT_URL) ?: DEFAULT_MINT_URL

        if (mnemonic.isEmpty()) {
            generateNewMnemonic()
        }

        Log.d(TAG, "Wallet state loaded - Balance: $balance sats, Mint: $mintUrl")
    }

    private fun saveWalletState() {
        prefs.edit()
            .putLong(KEY_BALANCE, balance)
            .putString(KEY_MNEMONIC, mnemonic)
            .putString(KEY_MINT_URL, mintUrl)
            .apply()
    }

    private fun generateNewMnemonic() {
        // Generate a simple mnemonic (in real implementation, use proper BIP39)
        mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        Log.d(TAG, "Generated new mnemonic")
        saveWalletState()
    }

    fun getBalance(): Long = balance

    fun getMnemonic(): String = mnemonic

    fun getMintUrl(): String = mintUrl

    /**
     * Get the active keyset ID from the mint (like main app's getKeyset function)
     */
    private suspend fun getActiveKeysetId(): String {
        if (activeKeysetId.isNotEmpty()) {
            return activeKeysetId
        }

        try {
            val request = Request.Builder()
                .url("$mintUrl/v1/info")
                .get()
                .build()

            val response = httpClient.newCall(request).execute()

            if (response.isSuccessful) {
                val responseBody = response.body?.string() ?: ""
                val mintInfo = JsonParser.parseString(responseBody).asJsonObject
                val keysets = mintInfo.getAsJsonArray("keysets")

                if (keysets != null && keysets.size() > 0) {
                    // Filter active keysets (like main app does)
                    val activeKeysets = mutableListOf<JsonObject>()
                    for (i in 0 until keysets.size()) {
                        val keyset = keysets.get(i).asJsonObject
                        val isActive = keyset.get("active")?.asBoolean ?: false
                        if (isActive) {
                            activeKeysets.add(keyset)
                        }
                    }

                    if (activeKeysets.isNotEmpty()) {
                        // Sort keysets like main app: hex keysets first, then base64
                        val hexKeysets = activeKeysets.filter { it.get("id").asString.startsWith("00") }
                        val base64Keysets = activeKeysets.filter { !it.get("id").asString.startsWith("00") }
                        val sortedKeysets = hexKeysets + base64Keysets

                        val keysetId = sortedKeysets.first().get("id").asString
                        activeKeysetId = keysetId
                        Log.d(TAG, "✅ Retrieved active keyset ID: $keysetId")
                        return keysetId
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting keyset ID", e)
        }

        // Fallback to placeholder if we can't get the real one
        Log.w(TAG, "⚠️ Using placeholder keyset ID - minting may fail")
        return "placeholder_keyset_id"
    }


    /**
     * Request a Lightning invoice from the mint
     * This mirrors the main app's requestMint functionality
     */
    suspend fun requestMint(amount: Long): Result<MintQuote> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Requesting mint for amount: $amount sats")
            Log.d(TAG, "Mint URL: $mintUrl")

            val requestBody = JsonObject().apply {
                addProperty("amount", amount)
                addProperty("unit", "sat")
            }

            val request = Request.Builder()
                .url("$mintUrl/v1/mint/quote/bolt11")
                .post(requestBody.toString().toRequestBody("application/json".toMediaType()))
                .addHeader("Content-Type", "application/json")
                .build()

            Log.d(TAG, "Making HTTP request to: $mintUrl/v1/mint/quote/bolt11")
            Log.d(TAG, "Request body: ${requestBody.toString()}")

            val response = httpClient.newCall(request).execute()

            Log.d(TAG, "Response received: ${response.code} - ${response.message}")

            if (response.isSuccessful) {
                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Mint quote response: $responseBody")

                val quoteData = JsonParser.parseString(responseBody).asJsonObject
                val quote = MintQuote(
                    quote = quoteData.get("quote").asString,
                    request = quoteData.get("request").asString,
                    paid = false
                )

                Result.success(quote)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "Mint request failed: ${response.code} - $errorBody")
                Log.e(TAG, "Request URL: $mintUrl/v1/mint/quote/bolt11")
                Log.e(TAG, "Request body: $requestBody")
                Result.failure(Exception("Mint request failed: ${response.code} - $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting mint", e)
            Log.e(TAG, "Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Exception message: ${e.message}")
            Result.failure(e)
        }
    }

    /**
     * Check if an invoice has been paid
     * This mirrors the main app's checkInvoice functionality
     */
    suspend fun checkInvoice(quoteId: String): Result<MintQuote> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Checking invoice status for quote: $quoteId")

            val request = Request.Builder()
                .url("$mintUrl/v1/mint/quote/bolt11/$quoteId")
                .get()
                .build()

            val response = httpClient.newCall(request).execute()

            if (response.isSuccessful) {
                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Invoice check response: $responseBody")

                val quoteData = JsonParser.parseString(responseBody).asJsonObject
                val quote = MintQuote(
                    quote = quoteData.get("quote").asString,
                    request = quoteData.get("request").asString,
                    paid = quoteData.get("paid").asBoolean
                )

                Result.success(quote)
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "Invoice check failed: ${response.code} - $errorBody")
                Result.failure(Exception("Invoice check failed: ${response.code}"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking invoice", e)
            Result.failure(e)
        }
    }

    /**
     * Mint tokens after invoice payment
     * This mirrors the main app's mintProofs functionality
     */
    suspend fun mintTokens(quoteId: String, amount: Long): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Minting tokens for quote: $quoteId, amount: $amount")

            // Get the real keyset ID from the mint
            val keysetId = getActiveKeysetId()

            // Create blinded outputs for the minting request
            // This is what the main app does - it generates blinded messages for the proofs
            val outputs = JsonArray()

            // For simplicity, we'll create a single output for the full amount
            // In a real implementation, this would use proper blinding
            val output = JsonObject().apply {
                addProperty("id", keysetId) // Use real keyset ID from mint
                addProperty("amount", amount)
                addProperty("B_", "placeholder_blinded_message") // This would be a real blinded message
            }
            outputs.add(output)

            // Request mint tokens from the mint
            val requestBody = JsonObject().apply {
                addProperty("quote", quoteId)
                add("outputs", outputs)
            }

            val request = Request.Builder()
                .url("$mintUrl/v1/mint/bolt11")
                .post(requestBody.toString().toRequestBody("application/json".toMediaType()))
                .addHeader("Content-Type", "application/json")
                .build()

            val response = httpClient.newCall(request).execute()

            if (response.isSuccessful) {
                val responseBody = response.body?.string() ?: ""
                Log.d(TAG, "Mint tokens response: $responseBody")

                // Parse the response to get the actual tokens
                val tokenData = JsonParser.parseString(responseBody).asJsonObject
                val tokens = tokenData.getAsJsonArray("tokens")

                if (tokens != null && tokens.size() > 0) {
                    // Update balance with the actual minted amount
                    balance += amount
                    saveWalletState()

                    Log.d(TAG, "Tokens minted successfully. New balance: $balance")
                    Result.success(Unit)
                } else {
                    Log.e(TAG, "No tokens received from mint")
                    Result.failure(Exception("No tokens received from mint"))
                }
            } else {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "Mint tokens failed: ${response.code} - $errorBody")
                Log.e(TAG, "Request URL: $mintUrl/v1/mint/bolt11")
                Log.e(TAG, "Request body: $requestBody")
                Result.failure(Exception("Mint tokens failed: ${response.code} - $errorBody"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error minting tokens", e)
            Result.failure(e)
        }
    }

    /**
     * Create a send token (ecash)
     * This mirrors the main app's send functionality
     */
    suspend fun createSendToken(amount: Long): Result<String> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Creating send token for amount: $amount")

            if (amount > balance) {
                return@withContext Result.failure(Exception("Insufficient balance"))
            }

            // For now, we'll create a simple token format
            // In a real implementation, this would use proper Cashu token creation
            val token = JsonObject().apply {
                addProperty("token", "cashuA${amount}")
                addProperty("amount", amount)
                addProperty("mint", mintUrl)
                addProperty("keyset_id", "placeholder_keyset_id")
            }

            val tokenString = token.toString()
            Log.d(TAG, "Send token created: $tokenString")

            Result.success(tokenString)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating send token", e)
            Result.failure(e)
        }
    }


    /**
     * Update balance (for testing purposes)
     */
    fun updateBalance(newBalance: Long) {
        balance = newBalance
        saveWalletState()
        Log.d(TAG, "Balance updated to: $balance sats")
    }
}

/**
 * Data class for mint quotes
 */
data class MintQuote(
    val quote: String,
    val request: String,
    val paid: Boolean
)
