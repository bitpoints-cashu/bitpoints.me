## Google Drive Seed Backup

This document explains how to configure and validate the Google Drive integration used to back up the Bitpoints wallet seed using a Recoverbull-compatible encrypted vault.

### Prerequisites

1. **Google Cloud project**  
   - Create (or reuse) a GCP project and enable the *Google Drive API*.  
   - Create an OAuth client ID for Android (`com.google.android.gms`), add the signing certificate SHA-1 hashes for both debug and release keystores.

2. **Google Services configuration**  
   - Download the generated `google-services.json`.  
   - Place the file in `android/app/google-services.json`. It is ignored by Git—store it securely.

3. **Install required SDKs**  
   - Android Studio (to generate SHA-1 hashes and run the app)  
   - Capacitor CLI and project dependencies (`npm install`)  
   - Ensure `gradlew` can access Google Maven repositories when resolving the new Drive dependencies.

### Building & Running

```bash
# Sync JS → native once the config and dependencies are in place
npx cap sync android

# Open the Android project
npx cap open android
```

Build and install the `appDebug` variant from Android Studio, or run:

```bash
cd android
./gradlew assembleDebug
```

### Feature Walkthrough

1. **Connect**  
   - From Settings → *Google Drive Backup* tap *Sign in with Google*.  
   - Approve the OAuth consent screen using an account that has Drive access.

2. **Back up**  
   - Tap *Backup Seed Phrase Now*.  
   - A vault key is generated; **store it securely**. This key is required to decrypt the backup during recovery.

3. **Restore**  
   - On a fresh install, open Settings → *Google Drive Backup*.  
   - Provide the saved vault key when prompted, then choose *Restore from Google Drive*.  
   - The mnemonic is decrypted and written back into the wallet store.

### Testing Checklist

- [ ] Sign-in succeeds and authentication state persists across app restarts.  
- [ ] Backup uploads a new entry under the Drive `appDataFolder`.  
- [ ] Vault key is displayed after backup, copy-to-clipboard works.  
- [ ] Restore fails with a helpful error when the vault key is missing or incorrect.  
- [ ] Restore succeeds when the correct vault key is provided.  
- [ ] Disconnect clears cached metadata and local vault key material.

### Troubleshooting

- **`Google Sign-in failed`** – confirm SHA-1 fingerprints match the keystore used to sign the APK; re-download `google-services.json` if fingerprints change.
- **Drive API quota / 403** – ensure the OAuth client is authorized for the selected account and the Drive API is enabled for the project.
- **Vault key lost** – the Google Drive backup cannot be decrypted without the vault key; prompt the user to verify it immediately after every backup.

Keep the vault key secure and treat it as sensitive as the mnemonic itself.

