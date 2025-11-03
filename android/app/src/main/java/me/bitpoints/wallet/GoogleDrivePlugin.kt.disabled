package me.bitpoints.wallet

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
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

@CapacitorPlugin(name = "GoogleDrive")
class GoogleDrivePlugin : Plugin() {

    companion object {
        private const val TAG = "GoogleDrivePlugin"
    }

    private var driveService: Drive? = null
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

    @PluginMethod
    fun connect(call: PluginCall) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val account = GoogleSignIn.getLastSignedInAccount(context)
                    ?: throw Exception("No signed in account")

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
                ).setApplicationName("BitPoints Wallet").build()

                withContext(Dispatchers.Main) {
                    call.resolve()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Google Sign-in error: $e")
                withContext(Dispatchers.Main) {
                    call.reject("Google Sign-in failed", e.message)
                }
            }
        }
    }

    @PluginMethod
    fun disconnect(call: PluginCall) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                googleSignIn.signOut()
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
                // Create encrypted vault structure (simplified for now)
                val vault = JSONObject().apply {
                    put("content", content)
                    put("timestamp", System.currentTimeMillis())
                }

                val filename = "${SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())}_encrypted_vault.json"

                val fileMetadata = File()
                    .setName(filename)
                    .setMimeType("application/json")
                    .setParents(listOf("appDataFolder"))

                val fileContent = vault.toString().byteInputStream()

                val driveFile = driveService!!.files().create(fileMetadata, com.google.api.client.http.ByteArrayContent("application/json", vault.toString().toByteArray()))
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
