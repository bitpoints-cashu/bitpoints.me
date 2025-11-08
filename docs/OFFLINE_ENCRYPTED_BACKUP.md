## Offline Encrypted Seed Backup

Bitpoints can export the wallet seed as an encrypted JSON file directly in the browser. The file never leaves your device—store it wherever you prefer (cloud drive, USB, password manager, etc.). You must remember the passphrase you choose; without it the file cannot be decrypted.

### Create a backup

1. Open the web app and go to **Settings → Encrypted Seed Backup**.
2. Enter and confirm a passphrase (minimum 6 characters). This passphrase is not stored anywhere.
3. (Optional) Add a short note that will be embedded in the encrypted file.
4. Click **Download Encrypted Seed**. A JSON file (e.g. `bitpoints-encrypted-vault-2025-11-08T13-57-42Z.json`) is generated. Store this file and the passphrase safely.

### Restore from a backup

1. In **Settings → Encrypted Seed Backup**, click **Upload Encrypted File** and select your JSON file, or paste the encrypted JSON payload into the text area.
2. Enter the original passphrase.
3. Click **Restore Seed From Encrypted Backup**. On success, the mnemonic in your wallet is replaced with the decrypted seed.

### Important notes

- The file contains only encrypted data—Bitpoints cannot recover it without the passphrase.
- Always clear the passphrase from the clipboard after use.
- Keep multiple copies of the encrypted file (e.g. offline storage + cloud) to avoid single points of failure.
- To verify a backup, restore it on a secondary device (with flight mode enabled) and confirm the mnemonic matches.

For Google Drive integration (Recoverbull-compatible), see [`docs/GOOGLE_DRIVE_BACKUP.md`](./GOOGLE_DRIVE_BACKUP.md).

