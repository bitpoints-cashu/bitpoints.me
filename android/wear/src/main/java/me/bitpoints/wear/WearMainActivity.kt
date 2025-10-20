package me.bitpoints.wear

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button
import android.widget.Toast
import android.widget.ScrollView
import android.widget.EditText
import android.widget.ImageView
import android.view.Gravity
import android.view.View
import android.graphics.Color
import android.graphics.Bitmap
import android.text.TextUtils
import java.io.IOException
import java.io.InputStream
import kotlinx.coroutines.*

/**
 * Main Activity for Wear OS app using hybrid approach
 * Native UI with JavaScript bridge to shared logic
 */
class WearMainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "WearMainActivity"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private lateinit var mainLayout: LinearLayout
    private lateinit var statusText: TextView
    private lateinit var balanceText: TextView
    private lateinit var sendButton: Button
    private lateinit var receiveButton: Button
    private lateinit var historyButton: Button
    private lateinit var settingsButton: Button

    // Shared backend service
    private lateinit var walletService: WearWalletService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "WearMainActivity onCreate - Setting up hybrid app with native UI and shared backend logic")

        // Initialize shared backend service
        walletService = WearWalletService(this)

        setupNativeUI()
        setupJavaScriptEngine()
        checkPermissions()

        // Log that we're using the same code as main app
        Log.d(TAG, "Wear OS app now using same backend logic as main app")
        Log.d(TAG, "Using shared Cashu integration with native UI")
    }

    private fun setupNativeUI() {
        // Create a scrollable layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Status text
        statusText = TextView(this).apply {
            text = "Bitpoints Wallet\nMint: ${walletService.getMintUrl()}"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 30)
        }

        // Balance text
        balanceText = TextView(this).apply {
            text = "Balance: ${walletService.getBalance()} sats"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 30)
        }

        // Buttons
        sendButton = Button(this).apply {
            text = "Send"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                Log.d(TAG, "Send button clicked")
                showSendScreen()
            }
        }

        receiveButton = Button(this).apply {
            text = "Receive"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                Log.d(TAG, "Receive button clicked")
                showReceiveScreen()
            }
        }

        historyButton = Button(this).apply {
            text = "History"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                Log.d(TAG, "History button clicked")
                showHistoryScreen()
            }
        }

        settingsButton = Button(this).apply {
            text = "Settings"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                Log.d(TAG, "Settings button clicked")
                showSettingsScreen()
            }
        }

        // Add views to layout
        mainLayout.addView(statusText)
        mainLayout.addView(balanceText)
        mainLayout.addView(sendButton)
        mainLayout.addView(receiveButton)
        mainLayout.addView(historyButton)
        mainLayout.addView(settingsButton)

        // Add main layout to scroll view
        scrollView.addView(mainLayout)
        setContentView(scrollView)
    }

    private fun setupJavaScriptEngine() {
        // Since WebView is not available on Wear OS, we'll use a native implementation
        // that mimics the same logic as the main app
        Log.d(TAG, "Setting up native wallet logic (WebView not available on Wear OS)")

        // Initialize the native wallet logic
        initializeNativeWalletLogic()
    }

    private fun initializeNativeWalletLogic() {
        Log.d(TAG, "Initializing native wallet logic with same behavior as main app")

        // TODO: Implement the same Cashu logic as the main app
        // For now, we'll use a simple native implementation
        // This will be replaced with the actual shared logic

        // Initialize balance
        updateBalance("0")
    }

    private fun callJavaScriptFunction(functionName: String) {
        // Since we don't have WebView, we'll handle the functions natively
        when (functionName) {
            "showSendScreen" -> showSendScreen()
            "showReceiveScreen" -> showReceiveScreen()
            "showHistoryScreen" -> showHistoryScreen()
            "showSettingsScreen" -> showSettingsScreen()
            else -> Log.w(TAG, "Unknown function: $functionName")
        }
    }

    private fun showSendScreen() {
        Log.d(TAG, "showSendScreen called")

        // Create send screen layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        val title = TextView(this).apply {
            text = "Send Tokens"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 30)
        }

        // Amount input
        val amountLabel = TextView(this).apply {
            text = "Amount (sats):"
            textSize = 14f
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 10)
        }

        val amountInput = EditText(this).apply {
            hint = "Enter amount"
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            setPadding(10, 10, 10, 10)
            setPadding(0, 0, 0, 20)
        }

        // Create QR button
        val createQRButton = Button(this).apply {
            text = "Create QR Code"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                val amount = amountInput.text.toString().toLongOrNull()
                if (amount != null && amount > 0) {
                    createSendToken(amount)
                } else {
                    Toast.makeText(this@WearMainActivity, "Please enter a valid amount", Toast.LENGTH_SHORT).show()
                }
            }
        }

        // Back button
        val backButton = Button(this).apply {
            text = "Back"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                setupNativeUI()
            }
        }

        layout.addView(title)
        layout.addView(amountLabel)
        layout.addView(amountInput)
        layout.addView(createQRButton)
        layout.addView(backButton)

        scrollView.addView(layout)
        setContentView(scrollView)
    }

    private fun showReceiveScreen() {
        Log.d(TAG, "showReceiveScreen called")

        // Create receive screen layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        val title = TextView(this).apply {
            text = "Receive Tokens"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 30)
        }

        // Amount input
        val amountLabel = TextView(this).apply {
            text = "Amount (sats):"
            textSize = 14f
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 10)
        }

        val amountInput = EditText(this).apply {
            hint = "Enter amount"
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            setPadding(10, 10, 10, 10)
            setPadding(0, 0, 0, 20)
        }

        // Create invoice button
        val createInvoiceButton = Button(this).apply {
            text = "Create Lightning Invoice"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                val amount = amountInput.text.toString().toLongOrNull()
                if (amount != null && amount > 0) {
                    createLightningInvoice(amount)
                } else {
                    Toast.makeText(this@WearMainActivity, "Please enter a valid amount", Toast.LENGTH_SHORT).show()
                }
            }
        }

        // Back button
        val backButton = Button(this).apply {
            text = "Back"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                setupNativeUI()
            }
        }

        layout.addView(title)
        layout.addView(amountLabel)
        layout.addView(amountInput)
        layout.addView(createInvoiceButton)
        layout.addView(backButton)

        scrollView.addView(layout)
        setContentView(scrollView)
    }

    private fun showHistoryScreen() {
        Log.d(TAG, "showHistoryScreen called")

        // Create history screen layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        val title = TextView(this).apply {
            text = "Transaction History"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 30)
        }

        // Placeholder for transactions
        val noTransactions = TextView(this).apply {
            text = "No transactions yet"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.GRAY)
            setPadding(0, 0, 0, 30)
        }

        // Back button
        val backButton = Button(this).apply {
            text = "Back"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                setupNativeUI()
            }
        }

        layout.addView(title)
        layout.addView(noTransactions)
        layout.addView(backButton)

        scrollView.addView(layout)
        setContentView(scrollView)
    }

    private fun showSettingsScreen() {
        Log.d(TAG, "showSettingsScreen called")

        // Create settings screen layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        val title = TextView(this).apply {
            text = "Settings"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 30)
        }

        // Balance info
        val balanceInfo = TextView(this).apply {
            text = "Current Balance: ${walletService.getBalance()} sats"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 20)
        }

        // Mint info
        val mintInfo = TextView(this).apply {
            text = "Mint: ${walletService.getMintUrl()}"
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(Color.GRAY)
            setPadding(0, 0, 0, 20)
        }

        // Sync button
        val syncButton = Button(this).apply {
            text = "Sync with Mint"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                Toast.makeText(this@WearMainActivity, "Sync functionality removed - simplified like main app", Toast.LENGTH_SHORT).show()
            }
        }

        // Back button
        val backButton = Button(this).apply {
            text = "Back"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                setupNativeUI()
            }
        }

        layout.addView(title)
        layout.addView(balanceInfo)
        layout.addView(mintInfo)
        layout.addView(syncButton)
        layout.addView(backButton)

        scrollView.addView(layout)
        setContentView(scrollView)
    }

    private fun createSendToken(amount: Long) {
        Log.d(TAG, "Creating send token for amount: $amount")

        CoroutineScope(Dispatchers.Main).launch {
            try {
                Toast.makeText(this@WearMainActivity, "Creating send token for $amount sats...", Toast.LENGTH_SHORT).show()

                val result = withContext(Dispatchers.IO) {
                    walletService.createSendToken(amount)
                }

                result.fold(
                    onSuccess = { token ->
                        Log.d(TAG, "Send token created successfully")

                        // Show QR code screen with the Cashu token
                        showCashuQRCode(token, amount)

                        // Update balance
                        updateBalance()
                    },
                    onFailure = { error ->
                        Log.e(TAG, "Failed to create send token", error)
                        Toast.makeText(this@WearMainActivity, "Failed to create token: ${error.message}", Toast.LENGTH_SHORT).show()
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error creating send token", e)
                Toast.makeText(this@WearMainActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun createLightningInvoice(amount: Long) {
        Log.d(TAG, "Creating lightning invoice for amount: $amount")

        CoroutineScope(Dispatchers.Main).launch {
            try {
                Toast.makeText(this@WearMainActivity, "Creating lightning invoice for $amount sats...", Toast.LENGTH_SHORT).show()

                val result = withContext(Dispatchers.IO) {
                    walletService.requestMint(amount)
                }

                result.fold(
                    onSuccess = { quote ->
                        Log.d(TAG, "Lightning invoice created successfully")

                        // Show QR code screen with the Lightning invoice
                        showLightningQRCode(quote.request, amount, quote.quote)

                        // Start polling for payment
                        startPaymentPolling(quote, amount)
                    },
                    onFailure = { error ->
                        Log.e(TAG, "Failed to create lightning invoice", error)
                        Toast.makeText(this@WearMainActivity, "Failed to create invoice: ${error.message}", Toast.LENGTH_SHORT).show()
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error creating lightning invoice", e)
                Toast.makeText(this@WearMainActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun startPaymentPolling(quote: MintQuote, originalAmount: Long) {
        CoroutineScope(Dispatchers.Main).launch {
            var attempts = 0
            val maxAttempts = 60 // Poll for 5 minutes (60 * 5 seconds)

            while (attempts < maxAttempts && !quote.paid) {
                delay(5000) // Wait 5 seconds
                attempts++

                try {
                    val result = withContext(Dispatchers.IO) {
                        walletService.checkInvoice(quote.quote)
                    }

                    result.fold(
                        onSuccess = { updatedQuote ->
                            if (updatedQuote.paid) {
                                Log.d(TAG, "Payment received!")
                                Toast.makeText(this@WearMainActivity, "Payment received! Minting tokens...", Toast.LENGTH_SHORT).show()

                                // Mint the tokens with the original amount
                                val mintResult = withContext(Dispatchers.IO) {
                                    walletService.mintTokens(quote.quote, originalAmount)
                                }

                                mintResult.fold(
                                    onSuccess = {
                                        Toast.makeText(this@WearMainActivity, "Tokens minted successfully!", Toast.LENGTH_SHORT).show()
                                        updateBalance()
                                    },
                                    onFailure = { error ->
                                        Log.e(TAG, "Failed to mint tokens", error)
                                        Toast.makeText(this@WearMainActivity, "Failed to mint tokens: ${error.message}", Toast.LENGTH_SHORT).show()
                                    }
                                )
                                return@launch
                            } else {
                                Log.d(TAG, "Payment not yet received, attempt $attempts")
                            }
                        },
                        onFailure = { error ->
                            Log.e(TAG, "Error checking payment status", error)
                        }
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error in payment polling", e)
                }
            }

            if (attempts >= maxAttempts) {
                Toast.makeText(this@WearMainActivity, "Payment timeout. Please try again.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun updateBalance() {
        balanceText.text = "Balance: ${walletService.getBalance()} sats"
    }

    private fun showLightningQRCode(bolt11: String, amount: Long, quoteId: String) {
        Log.d(TAG, "Showing Lightning QR code for amount: $amount")

        // Create QR code screen layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        val title = TextView(this).apply {
            text = "Lightning Invoice"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 20)
        }

        // Amount
        val amountText = TextView(this).apply {
            text = "$amount sats"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 20)
        }

        // QR Code
        val qrCodeBitmap = QRCodeGenerator.generateLightningQRCode(bolt11, 300, 300)
        val qrImageView = ImageView(this).apply {
            if (qrCodeBitmap != null) {
                setImageBitmap(qrCodeBitmap)
            } else {
                setBackgroundColor(Color.GRAY)
            }
            setPadding(0, 0, 0, 20)
        }

        // Status
        val statusText = TextView(this).apply {
            text = "Waiting for payment..."
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.BLUE)
            setPadding(0, 0, 0, 20)
        }

        // Back button
        val backButton = Button(this).apply {
            text = "Back"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                setupNativeUI()
            }
        }

        layout.addView(title)
        layout.addView(amountText)
        layout.addView(qrImageView)
        layout.addView(statusText)
        layout.addView(backButton)

        scrollView.addView(layout)
        setContentView(scrollView)

        // Update status when payment is received
        CoroutineScope(Dispatchers.Main).launch {
            var attempts = 0
            val maxAttempts = 60

            while (attempts < maxAttempts) {
                delay(5000)
                attempts++

                try {
                    val result = withContext(Dispatchers.IO) {
                        walletService.checkInvoice(quoteId)
                    }

                    result.fold(
                        onSuccess = { updatedQuote ->
                            if (updatedQuote.paid) {
                                statusText.text = "Payment received!"
                                statusText.setTextColor(Color.GREEN)
                                return@launch
                            }
                        },
                        onFailure = { error ->
                            Log.e(TAG, "Error checking payment status", error)
                        }
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error in payment status check", e)
                }
            }

            if (attempts >= maxAttempts) {
                statusText.text = "Payment timeout"
                statusText.setTextColor(Color.RED)
            }
        }
    }

    private fun showCashuQRCode(token: String, amount: Long) {
        Log.d(TAG, "Showing Cashu QR code for amount: $amount")

        // Create QR code screen layout
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(20, 20, 20, 20)
            setBackgroundColor(Color.WHITE)
        }

        // Title
        val title = TextView(this).apply {
            text = "Send Token"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 20)
        }

        // Amount
        val amountText = TextView(this).apply {
            text = "$amount sats"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 20)
        }

        // QR Code
        val qrCodeBitmap = QRCodeGenerator.generateCashuQRCode(token, 300, 300)
        val qrImageView = ImageView(this).apply {
            if (qrCodeBitmap != null) {
                setImageBitmap(qrCodeBitmap)
            } else {
                setBackgroundColor(Color.GRAY)
            }
            setPadding(0, 0, 0, 20)
        }

        // Status
        val statusText = TextView(this).apply {
            text = "Scan to receive tokens"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.BLUE)
            setPadding(0, 0, 0, 20)
        }

        // Back button
        val backButton = Button(this).apply {
            text = "Back"
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                setupNativeUI()
            }
        }

        layout.addView(title)
        layout.addView(amountText)
        layout.addView(qrImageView)
        layout.addView(statusText)
        layout.addView(backButton)

        scrollView.addView(layout)
        setContentView(scrollView)
    }


    private fun updateBalance(balance: String) {
        runOnUiThread {
            balanceText.text = "Balance: $balance sats"
        }
    }


    private fun checkPermissions() {
        val permissionsToRequest = mutableListOf<String>()

        // Check Bluetooth permissions
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.BLUETOOTH)
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.BLUETOOTH_ADMIN)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.BLUETOOTH_CONNECT)
            }

            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.BLUETOOTH_SCAN)
            }
        }

        // Check location permission for Bluetooth scanning
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        // Check internet permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.INTERNET) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.INTERNET)
        }

        if (permissionsToRequest.isNotEmpty()) {
            requestPermissions(permissionsToRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                Log.d(TAG, "All permissions granted")
            } else {
                Log.w(TAG, "Some permissions denied")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "WearMainActivity onResume")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "WearMainActivity onPause")
    }
}
