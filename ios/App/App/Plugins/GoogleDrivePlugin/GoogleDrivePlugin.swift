import Foundation
import Capacitor
import GoogleSignIn
import GoogleAPIClientForREST_Drive

@objc(GoogleDrivePlugin)
public class GoogleDrivePlugin: CAPPlugin {

    private var driveService: GTLRDriveService?
    private var signInConfig: GIDConfiguration?

    override public func load() {
        super.load()

        // Configure Google Sign-In
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            signInConfig = GIDConfiguration(clientID: clientId)
        }
    }

    private func checkConnection() throws {
        if driveService == nil {
            throw NSError(domain: "GoogleDrivePlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "unauthenticated"])
        }
    }

    @objc func connect(_ call: CAPPluginCall) {
        guard let signInConfig = signInConfig else {
            call.reject("Google Sign-In not configured. Missing GOOGLE_CLIENT_ID in Info.plist")
            return
        }

        let presentingViewController = bridge?.viewController

        GIDSignIn.sharedInstance.signIn(with: signInConfig, presenting: presentingViewController!) { user, error in
            if let error = error {
                call.reject("Google Sign-in failed", error.localizedDescription)
                return
            }

            guard let user = user else {
                call.reject("Google Sign-in failed", "No user returned")
                return
            }

            // Create Drive service
            self.driveService = GTLRDriveService()
            self.driveService?.authorizer = user.fetcherAuthorizer()

            call.resolve()
        }
    }

    @objc func disconnect(_ call: CAPPluginCall) {
        GIDSignIn.sharedInstance.signOut()
        driveService = nil
        call.resolve()
    }

    @objc func store(_ call: CAPPluginCall) {
        do {
            try checkConnection()
        } catch {
            call.reject("Not authenticated", error.localizedDescription)
            return
        }

        guard let content = call.getString("content") else {
            call.reject("Content is required")
            return
        }

        // Create encrypted vault structure (simplified for now)
        let vault: [String: Any] = [
            "content": content,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: vault),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            call.reject("Failed to serialize vault data")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "\(dateFormatter.string(from: Date()))_encrypted_vault.json"

        // Create file metadata
        let file = GTLRDrive_File()
        file.name = filename
        file.mimeType = "application/json"
        file.parents = ["appDataFolder"]

        // Create file content
        let uploadParameters = GTLRUploadParameters(data: jsonString.data(using: .utf8)!, mimeType: "application/json")

        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
        query.fields = "id"

        driveService?.executeQuery(query) { ticket, file, error in
            if let error = error {
                call.reject("Failed to save to Google Drive", error.localizedDescription)
                return
            }

            call.resolve()
        }
    }

    @objc func fetchAllMetadata(_ call: CAPPluginCall) {
        do {
            try checkConnection()
        } catch {
            call.reject("Not authenticated", error.localizedDescription)
            return
        }

        let query = GTLRDriveQuery_FilesList.query()
        query.spaces = "appDataFolder"
        query.q = "mimeType='application/json' and trashed=false"
        query.fields = "files(id, name, createdTime)"
        query.orderBy = "createdTime desc"

        driveService?.executeQuery(query) { ticket, result, error in
            if let error = error {
                call.reject("Failed to fetch backup metadata", error.localizedDescription)
                return
            }

            guard let fileList = result as? GTLRDrive_FileList,
                  let files = fileList.files else {
                call.reject("Invalid response from Google Drive")
                return
            }

            let fileObjects = files.map { file -> [String: Any] in
                return [
                    "id": file.identifier ?? "",
                    "name": file.name ?? "",
                    "createdTime": file.createdTime?.dateTimeString ?? ""
                ]
            }

            call.resolve(["files": fileObjects])
        }
    }

    @objc func fetchFileContent(_ call: CAPPluginCall) {
        do {
            try checkConnection()
        } catch {
            call.reject("Not authenticated", error.localizedDescription)
            return
        }

        guard let fileId = call.getString("fileId") else {
            call.reject("fileId is required")
            return
        }

        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileId)

        driveService?.executeQuery(query) { ticket, file, error in
            if let error = error {
                call.reject("Failed to fetch backup content", error.localizedDescription)
                return
            }

            if let data = file as? Data,
               let content = String(data: data, encoding: .utf8) {
                call.resolve(["content": content])
            } else {
                call.reject("Invalid file content")
            }
        }
    }

    @objc func trash(_ call: CAPPluginCall) {
        do {
            try checkConnection()
        } catch {
            call.reject("Not authenticated", error.localizedDescription)
            return
        }

        guard let path = call.getString("path") else {
            call.reject("path is required")
            return
        }

        // First, find the file by name
        let listQuery = GTLRDriveQuery_FilesList.query()
        listQuery.spaces = "appDataFolder"
        listQuery.q = "name = '\(path)' and trashed = false"
        listQuery.fields = "files(id)"

        driveService?.executeQuery(listQuery) { ticket, result, error in
            if let error = error {
                call.reject("Failed to find backup file", error.localizedDescription)
                return
            }

            guard let fileList = result as? GTLRDrive_FileList,
                  let files = fileList.files,
                  let file = files.first,
                  let fileId = file.identifier else {
                call.reject("Backup file not found")
                return
            }

            // Now trash the file
            let updateFile = GTLRDrive_File()
            updateFile.trashed = true

            let updateQuery = GTLRDriveQuery_FilesUpdate.query(withObject: updateFile, fileId: fileId, uploadParameters: nil)

            self.driveService?.executeQuery(updateQuery) { ticket, file, error in
                if let error = error {
                    call.reject("Failed to delete backup", error.localizedDescription)
                    return
                }

                call.resolve()
            }
        }
    }
}
