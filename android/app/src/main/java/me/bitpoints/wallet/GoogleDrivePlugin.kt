package me.bitpoints.wallet

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import com.google.api.client.googleapis.extensions.android.gms.auth.GoogleAccountCredential
import com.google.api.client.http.javanet.NetHttpTransport
import com.google.api.client.json.gson.GsonFactory
import com.google.api.services.drive.Drive
import com.google.api.services.drive.DriveScopes
import com.google.api.services.drive.model.File
import com.google.api.services.drive.model.FileList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

@CapacitorPlugin(name = "GoogleDrive")
class GoogleDrivePlugin : Plugin() {

    companion object {
        private const val TAG = "GoogleDrivePlugin"
        private const val RC_SIGN_IN = 9001
    }

    private var driveService: Drive? = null
    private var pendingConnectCall: PluginCall? = null

    private val googleSignIn by lazy {
        GoogleSignIn.getClient(
            context,
            GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestScopes(Scope(DriveScopes.DRIVE_APPDATA))
                .build()
        )
    }

    private fun checkConnection() {
        if (driveService == null) {
            throw Exception("unauthenticated")
        }
    }

    private fun buildDriveService(account: GoogleSignInAccount) {
        val credential = GoogleAccountCredential.usingOAuth2(
            context,
            listOf(DriveScopes.DRIVE_APPDATA)
        ).apply {
            selectedAccount = account.account
        }

        driveService = Drive.Builder(
            NetHttpTransport(),
            GsonFactory.getDefaultInstance(),
            credential
        ).setApplicationName("Bitpoints Wallet").build()
    }

    private fun resolvePendingConnect() {
        val call = pendingConnectCall ?: return
        pendingConnectCall = null
        call.resolve()
    }

    private fun rejectPendingConnect(message: String, error: Throwable? = null) {
        val call = pendingConnectCall ?: return
        pendingConnectCall = null
        call.reject(message, error?.message, error)
    }

    override fun handleOnActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.handleOnActivityResult(requestCode, resultCode, data)

        if (requestCode != RC_SIGN_IN) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            Log.e(TAG, "Google Sign-in cancelled or failed with resultCode=$resultCode")
            rejectPendingConnect("Google Sign-in cancelled")
            return
        }

        try {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            val account = task.result
            if (account == null) {
                Log.e(TAG, "Google Sign-in returned null account")
                rejectPendingConnect("Google Sign-in failed: account unavailable")
                return
            }

            CoroutineScope(Dispatchers.IO).launch {
                try {
                    buildDriveService(account)
                    withContext(Dispatchers.Main) {
                        resolvePendingConnect()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to initialize Drive service", e)
                    withContext(Dispatchers.Main) {
                        rejectPendingConnect("Failed to initialize Google Drive", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Google Sign-in error", e)
            rejectPendingConnect("Google Sign-in failed", e)
        }
    }

    @PluginMethod
    fun connect(call: PluginCall) {
        if (driveService != null) {
            call.resolve()
            return
        }

        val lastAccount = GoogleSignIn.getLastSignedInAccount(context)
        if (lastAccount != null) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    buildDriveService(lastAccount)
                    withContext(Dispatchers.Main) {
                        call.resolve()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to reuse last signed-in account", e)
                    withContext(Dispatchers.Main) {
                        call.reject("Failed to initialize Google Drive", e.message)
                    }
                }
            }
            return
        }

        synchronized(this) {
            if (pendingConnectCall != null) {
                call.reject("Google Sign-in already in progress")
                return
            }
            pendingConnectCall = call
        }

        try {
            val intent = googleSignIn.signInIntent
            startActivityForResult(call, intent, RC_SIGN_IN)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch Google Sign-in intent", e)
            rejectPendingConnect("Failed to launch Google Sign-in intent", e)
        }
    }

    @PluginMethod
    fun disconnect(call: PluginCall) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                googleSignIn.signOut()
                googleSignIn.revokeAccess()
                driveService = null
                withContext(Dispatchers.Main) {
                    call.resolve()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Google Sign-out error: $e")
                withContext(Dispatchers.Main) {
                    call.reject("Google Sign-out failed", e.message)
                }
            }
        }
    }

    @PluginMethod
    fun store(call: PluginCall) {
        checkConnection()

        val content = call.getString("content") ?: run {
            call.reject("Content is required")
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val filename = "${SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())}_encrypted_vault.json"

                val fileMetadata = File().apply {
                    name = filename
                    mimeType = "application/json"
                    parents = listOf("appDataFolder")
                }

                val byteContent = content.toByteArray(Charsets.UTF_8)
                val mediaContent = com.google.api.client.http.ByteArrayContent("application/json", byteContent)

                val driveFile = driveService!!.files()
                    .create(fileMetadata, mediaContent)
                    .setFields("id")
                    .execute()

                Log.d(TAG, "File uploaded successfully: ${driveFile.id}")

                withContext(Dispatchers.Main) {
                    call.resolve()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to store backup: $e")
                withContext(Dispatchers.Main) {
                    call.reject("Failed to save to Google Drive", e.message)
                }
            }
        }
    }

    @PluginMethod
    fun fetchAllMetadata(call: PluginCall) {
        checkConnection()

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val result = driveService!!.files().list()
                    .setSpaces("appDataFolder")
                    .setQ("mimeType='application/json' and trashed=false")
                    .setFields("files(id, name, createdTime)")
                    .setOrderBy("createdTime desc")
                    .execute()

                val files = result.files.map { file ->
                    JSObject().apply {
                        put("id", file.id)
                        put("name", file.name)
                        put("createdTime", file.createdTime.toString())
                    }
                }

                val response = JSObject().apply {
                    put("files", files)
                }

                withContext(Dispatchers.Main) {
                    call.resolve(response)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch metadata: $e")
                withContext(Dispatchers.Main) {
                    call.reject("Failed to fetch backup metadata", e.message)
                }
            }
        }
    }

    @PluginMethod
    fun fetchFileContent(call: PluginCall) {
        checkConnection()

        val fileId = call.getString("fileId") ?: run {
            call.reject("fileId is required")
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val outputStream = ByteArrayOutputStream()
                driveService!!.files()
                    .get(fileId)
                    .executeMediaAndDownloadTo(outputStream)

                val content = outputStream.toString("UTF-8")

                val response = JSObject().apply {
                    put("content", content)
                }

                withContext(Dispatchers.Main) {
                    call.resolve(response)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch file content: $e")
                withContext(Dispatchers.Main) {
                    call.reject("Failed to fetch backup content", e.message)
                }
            }
        }
    }

    @PluginMethod
    fun trash(call: PluginCall) {
        checkConnection()

        val path = call.getString("path") ?: run {
            call.reject("path is required")
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Find file by name
                val fileList = driveService!!.files().list()
                    .setSpaces("appDataFolder")
                    .setQ("name = '$path' and trashed = false")
                    .setFields("files(id)")
                    .execute()

                val fileId = fileList.files?.firstOrNull()?.id
                    ?: throw Exception("Backup file not found")

                // Mark as trashed
                val file = File().setTrashed(true)
                driveService!!.files().update(fileId, file).execute()

                withContext(Dispatchers.Main) {
                    call.resolve()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to trash backup: $e")
                withContext(Dispatchers.Main) {
                    call.reject("Failed to delete backup", e.message)
                }
            }
        }
    }
}
