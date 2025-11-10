## RecoverBull Backup

The wallet now implements the full RecoverBull protocol for mnemonic backups. This replaces the former Google Drive backup feature and uses the RecoverBull key server hosted at `http://keys.bitpints.me`.

### Backup Flow

1. Collect the mnemonic words and the password supplied by the user.
2. Derive the backup key deterministically from the wallet seed using the RecoverBull BIP85 path (`1608'/0'/index'`).
3. Encrypt the mnemonic payload with AES-CBC/PKCS7 + HMAC-SHA256 using the derived backup key.
4. Persist the encrypted payload as a `BullBackup` JSON file:
   ```json
   {
     "created_at": 1730956800000,
     "id": "<32 byte hex>",
     "ciphertext": "<base64 nonce+ciphertext+hmac>",
     "salt": "<16 byte hex>",
     "path": "1608'/0'/42'"
   }
   ```
5. Derive authentication and encryption keys from the user password via Argon2id (t=2, m=19 MiB, p=1, dkLen=64) using the `salt` contained in the backup file.
6. Encrypt the backup key with the password-derived encryption key and upload it to the key server together with the backup identifier and authentication key.
7. Offer the backup JSON to the user for download and provide a clipboard copy helper.

### Restore Flow

1. The user supplies the backup JSON and password.
2. Parse and validate the `BullBackup` payload.
3. Derive the password keys (same Argon2id parameters) and fetch the encrypted backup key from the key server.
4. Decrypt the backup key, then decrypt the mnemonic payload with AES-CBC/PKCS7 + HMAC-SHA256.
5. Restore the mnemonic into the wallet store.

### Key Server Integration

- Base URL: `http://keys.bitpints.me`
- Endpoints used:
  - `POST /store` – persist encrypted backup key (expects HTTP 201)
  - `POST /fetch` – retrieve encrypted backup key (expects HTTP 200)
  - `POST /trash` – delete encrypted backup key (expects HTTP 202)
  - `GET /info` – diagnostic endpoint used to display rate limiting metadata
- Errors returned by the server propagate through `RecoverbullKeyServerError`, which exposes the HTTP status, cooldown, attempts, and timestamp so the UI can render helpful notices.

### Testing

Vitest coverage for the RecoverBull implementation lives in:

- `test/vitest/__tests__/recoverbullVault.spec.ts` – unit tests for cryptographic helpers and Argon2 parameters.
- `test/vitest/__tests__/recoverbullBackup.store.spec.ts` – integration test for the backup store that exercises the key-server flow.

Run the suite with:

```bash
npm run test
```

or target an individual file:

```bash
npm run test -- --run test/vitest/__tests__/recoverbullBackup.store.spec.ts
```

### QA Checklist

- [ ] Creating a backup downloads the JSON file and surfaces the backup identifier.
- [ ] Copy-to-clipboard for the backup JSON works (desktop and mobile).
- [ ] Restoring with the correct password rebuilds the mnemonic and hides it by default.
- [ ] Incorrect password produces a descriptive error and does not mutate the wallet.
- [ ] Key server rate limit messages appear when cooldown metadata is returned.

