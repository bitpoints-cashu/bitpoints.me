## RecoverBull End-to-End Implementation Guide

This document captures everything required to reproduce the RecoverBull backup stack on a clean machine. It covers the wallet client, the RecoverBull key server, and legacy Google Drive backup notes for reference. Use it as a hand-off checklist when setting up new environments or onboarding contributors.

---

### 1. Git Repositories

| Component | Repository | Purpose |
|-----------|------------|---------|
| Wallet (this project) | `https://github.com/bitpoints-cashu/bitpoints.me.git` | Quasar/Vue3 application implementing RecoverBull backup UX |
| Key server reference | `https://github.com/SatoshiPortal/recoverbull-server.git` | Falcon/Dart RecoverBull server implementation |
| Client reference | `https://github.com/SatoshiPortal/recoverbull-client-dart.git` | Cryptographic reference for BIP85/Argon2 helpers |
| Google Drive (legacy) | _none bundled_ – refer to previous tag `v1.3.0-gdrive-backup` | Historical Drive backup flow, kept for comparison |

Clone each repository you need into your development workspace. This wallet repo already includes the RecoverBull client logic; the server repo is needed for backend deployments.

---

### 2. Wallet Setup (RecoverBull Client)

1. **Dependencies**
   - Node.js ≥ 20
   - pnpm (recommended) or npm
   - Android/iOS SDKs only if targeting native builds (PWA does not require them)

2. **Installation**
   ```bash
   git clone https://github.com/bitpoints-cashu/bitpoints.me.git
   cd bitpoints.me
   pnpm install    # or npm install
   ```

3. **Environment Variables**
   Create a `.env` file (or `.env.local` for Quasar) with at least:
   ```
   VITE_RECOVERBULL_KEY_SERVER_URL=http://keys.bitpints.me
   ```
   Override the URL for staging/prod key server deployments as required.

4. **Scripts**
   - `pnpm run dev` – local development server (PWA-friendly)
   - `pnpm run build` – Quasar production build
   - `pnpm run test` – Vitest unit/integration suite, including RecoverBull cryptography and store tests

5. **Key Files**
   - `src/utils/recoverbullVault.ts` – Argon2id, AES-CBC/PKCS7, HMAC helpers, BIP85 derivation
   - `src/services/recoverbullKeyServer.ts` – Axios client wrapping `/info`, `/store`, `/fetch`, `/trash`
   - `src/stores/recoverbullKeyServer.ts` – Pinia store handling rate limits, errors, server base URL
   - `src/stores/recoverbullBackup.ts` – Wraps vault creation/restoration and key-server calls
   - `src/components/SettingsView.vue` – Backup/restore UI for RecoverBull (password input, download, restore)

6. **Testing Checklist**
   - `pnpm run test -- --run test/vitest/__tests__/recoverbullVault.spec.ts`
   - `pnpm run test -- --run test/vitest/__tests__/recoverbullBackup.store.spec.ts`
   - Manual: Create backup, download JSON, restore with correct password, verify rate-limit messaging

7. **PWA Support**
   The RecoverBull flow works in browsers/PWA. Ensure HTTPS is used so WebCrypto and Clipboard APIs remain available.

---

### 3. RecoverBull Key Server Deployment

1. **Clone & Install**
   ```bash
   git clone https://github.com/SatoshiPortal/recoverbull-server.git
   cd recoverbull-server
   dart pub get
   ```
   Alternatively, you can build a Node/Express equivalent using the same API contract if you prefer JS.

2. **Environment Configuration**
   Create `.env` with:
   ```
   PORT=8080
   DATABASE_URL=postgres://user:pass@host:5432/recoverbull
   COOL_DOWN_MINUTES=15
   MAX_ATTEMPTS=5
   WARRANT_CANARY="Never been compelled"
   CANARY_SIGNATURE="..."            # optional Ed25519/signature block
   ```
   Adjust to match infrastructure and security policies.

3. **Database**
   - Use PostgreSQL or another durable KV store.
   - Store fields: `identifier` (hex), `authentication_key_hash`, `encrypted_secret` (base64), `attempts`, `requested_at`.
   - Enforce unique constraint on `identifier`.

4. **Endpoints**
   - `POST /store` – expects `{identifier, authentication_key, encrypted_secret}`; responds `201`
   - `POST /fetch` – same payload (sans secret); returns encrypted secret, responds `200`
   - `POST /trash` – same as fetch; deletes record; responds `202`
   - `GET /info` – returns `{cooldown_minutes, max_attempts, canary, signature, version}`

5. **Security**
   - Terminate TLS at a reverse proxy (nginx, Caddy, CloudFront).
   - Optionally guard `/store` with basic auth or IP allow-lists for administrative scenarios.
   - Implement consistent request logging for auditing.

6. **Rate Limiting**
   - Increment attempt counter on each fetch/trash request.
   - If `attempts >= MAX_ATTEMPTS`, set `requested_at = now` and refuse further attempts until `requested_at + cooldown`.
   - Return cooldown metadata in error responses so the wallet UI can display it.

7. **Deployment**
   - Build Docker image (if using Dockerfile from repo), push to registry.
   - Run behind load balancer with health check hitting `/info`.
   - Monitor logs for spikes in failed attempts or unauthorized access.

8. **Maintenance**
   - Rotate canary message/signature periodically and document the process.
   - Provide tooling to revoke identifiers (trash) and reset attempt counters if necessary.
   - Keep Argon2 parameters in sync with the wallet (`t=2`, `m=19MiB`, `p=1`, `dkLen=64`).

---

### 4. Google Drive (Legacy Reference)

RecoverBull has replaced Google Drive backups in `main`. If you need to revisit the Drive flow:

1. Check out tag `v1.3.0-gdrive-backup`.
2. Reinstate Capacitor plugin registration (`GoogleDrivePlugin`) and `src/stores/googleDriveBackup.ts`.
3. OAuth requirements:
   - `google-services.json` on Android, `GoogleService-Info.plist` on iOS.
   - Drive API enabled, OAuth scope `https://www.googleapis.com/auth/drive.appdata`.
4. The Drive flow relied on the same RecoverBull vault format; only storage medium differs.

Use this only for historical or migration references—the current release is RecoverBull-only.

---

### 5. Operational Checklists

**Wallet Release Steps**
1. Confirm `VITE_RECOVERBULL_KEY_SERVER_URL` set appropriately.
2. Run unit/integration tests.
3. Build Quasar bundles (`pnpm run build`).
4. Update release notes highlighting RecoverBull changes and password requirements.
5. Tag release (`git tag vX.Y.Z-recoverbull`), push to GitHub.

**Key Server Release Steps**
1. Run server unit tests / integration tests.
2. Apply DB migrations if schema changed.
3. Deploy to staging, smoke test with wallet pointing to staging URL.
4. Promote to production, update `VITE_RECOVERBULL_KEY_SERVER_URL` if needed.
5. Update canary message if part of release cadence.

**Disaster Recovery**
- Back up key server database regularly (identifiers + encrypted secrets).
- Document procedure for recovering from data loss (users must retain their backup JSON + password; server only stores encrypted backup keys).
- Provide support script to export identifiers and rate-limit status for audit.

---

### 6. Additional Resources

- RecoverBull site: `https://recoverbull.com/how-it-works`
- Reference client (Dart): `recoverbull-client-dart/lib/src/services/`
- Reference server (Dart/Falcon): `recoverbull-server/lib/src/`
- Wallet documentation: `docs/RECOVERBULL_BACKUP.md`, `docs/OFFLINE_ENCRYPTED_BACKUP.md`

Keep this file updated as the stack evolves to ensure new team members can bootstrap both client and server quickly.

