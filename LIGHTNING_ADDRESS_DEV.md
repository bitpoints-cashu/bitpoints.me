# Lightning Address Development Branch

## Overview

This branch contains development work for integrating custom Lightning addresses with Trails Coffee Rewards PWA. The implementation allows users to claim personalized Lightning addresses (e.g., `jpg@trailscoffee.com`) and automatically receive Bitcoin payments as ecash tokens.

## Features

### 1. Custom Username Registration
- **Page**: `/npub` - Dedicated Lightning address management page
- **Functionality**: Users can claim custom usernames like `username@trailscoffee.com`
- **Validation**: Real-time username availability checking
- **Payment**: One-time 5000 sat fee to claim username
- **UI**: Beautiful Trails Coffee branded interface

### 2. Automatic Lightning Payment Claiming
- **Worker**: Periodic background checks every 30 seconds
- **Store**: `src/stores/workers.ts` - Lightning address check worker
- **Conversion**: Automatically converts Lightning payments to ecash tokens
- **Notification**: User notifications when payments are received and claimed

### 3. Lightning Address Configuration
- **Domain**: `@trailscoffee.com` (user-facing)
- **Backend**: `npubcash.trailscoffee.com` (API server)
- **Mint**: `ecash.trailscoffee.com` (ecash mint)
- **Settings**: Configurable domain in Settings page

### 4. QR Code Features
- **Display**: QR codes for Lightning addresses in multiple locations
- **Settings**: QR code icon next to Lightning address copy button
- **NPUB Page**: Large QR code for easy scanning and sharing
- **Payment**: QR codes for username claiming invoices

## Architecture

### Frontend (cashu.me PWA)

#### New Components
- **`src/pages/NpubPage.vue`**: Lightning address management page
  - Username registration UI
  - Availability checking
  - Payment flow with QR codes
  - Address display and sharing

#### Modified Components
- **`src/pages/WalletPage.vue`**:
  - Added "Lightning Address" button
  - Added `goToNpubPage()` method
  - Integrated Lightning address check worker on mount

- **`src/components/SettingsView.vue`**:
  - Added domain configuration field
  - Added QR code button next to Lightning address
  - Added QR code dialog for address sharing
  - Added `updateNPCConnection()` method

#### Modified Stores
- **`src/stores/npubcash.ts`**:
  - Changed default domain to `trailscoffee.com`
  - Changed default baseURL to `https://npubcash.trailscoffee.com`
  - Changed default `npcEnabled` to `true`
  - Added logic to use `npubcash.trailscoffee.com` when domain is `trailscoffee.com`

- **`src/stores/workers.ts`**:
  - Added `lightningAddressCheckListener` state
  - Added `lightningAddressWorkerRunning` state
  - Added `lightningAddressCheckInterval` (30000ms)
  - Added `lightningAddressCheckWorker()` action
  - Updated `clearAllWorkers()` to include Lightning address worker

#### Routing
- **`src/router/routes.js`**: Added `/npub` route with MainLayout

### Backend (npubcash-server)

The backend server at `npubcash.trailscoffee.com` requires the following configuration:

#### Required Environment Variables
```bash
# Database
PGUSER=your_db_user
PGPASSWORD=your_db_password
PGHOST=your_db_host
PGDATABASE=your_db_name
PGPORT=5432

# CRITICAL: Trails Coffee Mint
MINTURL=https://ecash.trailscoffee.com

# Blink API (Lightning payment processing)
BLINK_API_KEY=your_blink_api_key
BLINK_WALLET_ID=your_blink_wallet_id
BLINK_URL=https://api.blink.sv/graphql

# Authentication
JWT_SECRET=your_random_secret_key

# Nostr (for NIP-57 zaps)
ZAP_SECRET_KEY=your_nostr_private_key

# LNURL limits (in millisats)
LNURL_MIN_AMOUNT=1000
LNURL_MAX_AMOUNT=1000000000

# Domain
HOSTNAME=https://npubcash.trailscoffee.com
```

#### API Endpoints Used

**1. Check Username Availability / Claim Username**
```http
PUT /api/v1/info/username
Authorization: Nostr <NIP-98-token>
Content-Type: application/json

Body (check availability):
{
  "username": "jpg"
}

Response (available):
{
  "data": {
    "paymentRequest": "lnbc...",
    "paymentToken": "jwt-token"
  }
}

Body (after payment):
{
  "username": "jpg",
  "paymentToken": "jwt-token"
}

Response (success):
{
  "username": "jpg",
  "npub": "npub1...",
  "mintUrl": "https://ecash.trailscoffee.com"
}
```

**2. Get User Info**
```http
GET /api/v1/info
Authorization: Nostr <NIP-98-token>

Response:
{
  "username": "jpg",
  "npub": "npub1...",
  "mintUrl": "https://ecash.trailscoffee.com"
}
```

**3. Get Balance**
```http
GET /api/v1/balance
Authorization: Nostr <NIP-98-token>

Response:
{
  "data": 1000,  // sats available to claim
  "error": null
}
```

**4. Claim Tokens**
```http
GET /api/v1/claim
Authorization: Nostr <NIP-98-token>

Response:
{
  "data": {
    "token": "cashuA..."  // ecash token
  },
  "error": null
}
```

## User Flow

### First-Time User (No Custom Username)

1. **Enable Lightning Address**: Settings → Enable Lightning address toggle
2. **Auto-Generated Address**: System creates `npub1xxxxx@trailscoffee.com`
3. **Claim Custom Username** (Optional):
   - Click "Lightning Address" button on main page
   - Navigate to `/npub` page
   - Enter desired username (e.g., `jpg`)
   - System checks availability
   - Click "Claim Username (5000 sats)"
   - Pay Lightning invoice (QR code shown)
   - System monitors payment
   - Address updates to `jpg@trailscoffee.com`

### Receiving Lightning Payments

1. **Share Address**: User shares `jpg@trailscoffee.com` (or QR code)
2. **Sender Pays**: Someone sends Bitcoin to the address
3. **Backend Processing**:
   - Blink API receives Lightning payment
   - npubcash server converts to ecash token (using MINTURL)
   - Token stored in database for user
4. **Frontend Claiming**:
   - Worker checks balance every 30 seconds
   - Detects available balance > 0
   - Automatically claims ecash token
   - Redeems token to wallet
   - Balance updates in UI

## Technical Implementation

### NIP-98 Authentication

All API calls to npubcash server use NIP-98 authentication:

```typescript
const generateNip98Event = async (url: string, method: string): Promise<string> => {
  await nostrStore.initSignerIfNotSet();
  const nip98Event = new NDKEvent(new NDK());
  nip98Event.kind = 27235;  // NIP-98 kind
  nip98Event.content = "";
  nip98Event.tags = [
    ["u", url],
    ["method", method],
  ];
  const sig = await nip98Event.sign(nostrStore.signer);
  const eventString = JSON.stringify(nip98Event.rawEvent());
  return btoa(eventString);  // Base64 encode
};

// Use in fetch:
headers: {
  "Authorization": `Nostr ${authHeader}`
}
```

### Periodic Claim Checking

```typescript
// In src/stores/workers.ts
lightningAddressCheckWorker: async function () {
  const npcStore = useNPCStore();
  if (!npcStore.npcEnabled) return;

  this.lightningAddressWorkerRunning = true;
  this.lightningAddressCheckListener = setInterval(async () => {
    await npcStore.claimAllTokens();  // Check and claim if balance > 0
  }, this.lightningAddressCheckInterval);  // 30000ms
}
```

### Automatic Token Claiming

```typescript
// In src/stores/npubcash.ts
claimAllTokens: async function () {
  if (!this.npcEnabled) return;

  const npubCashBalance = await this.getBalance();

  if (npubCashBalance > 0) {
    notifySuccess(`You have ${npubCashBalance} sats on npub.cash`);
    const token = await this.getClaim();

    if (token) {
      this.addPendingTokenToHistory(token);
      receiveStore.receiveData.tokensBase64 = token;

      if (this.automaticClaim) {
        await walletStore.redeem();  // Auto-redeem to wallet
      } else {
        receiveStore.showReceiveTokens = true;  // Show manual claim dialog
      }
    }
  }
}
```

## Files Modified/Created

### New Files
- `src/pages/NpubPage.vue` - Lightning address management page
- `src/components/BackupKeysCard.vue` - Nostr keys backup component (unused)
- `src/components/UsernameSignup.vue` - Username signup component (unused)

### Modified Files
- `src/pages/WalletPage.vue` - Added Lightning Address button
- `src/components/SettingsView.vue` - Added domain config and QR code
- `src/stores/npubcash.ts` - Updated defaults for Trails Coffee
- `src/stores/workers.ts` - Added Lightning address check worker
- `src/router/routes.js` - Added `/npub` route

## Testing

### Prerequisites
1. npubcash server running at `npubcash.trailscoffee.com`
2. Server configured with `MINTURL=https://ecash.trailscoffee.com`
3. Blink API credentials configured
4. PostgreSQL database set up
5. Webhook configured at Blink dashboard: `https://npubcash.trailscoffee.com/api/v1/paid`

### Test Steps

#### Test 1: Default Lightning Address
1. Open PWA: `http://localhost:8080`
2. Go to Settings
3. Verify Lightning address toggle is ON by default
4. Verify address shows as `npub1xxxxx@trailscoffee.com`
5. Click QR code icon to see QR dialog

#### Test 2: Custom Username Claiming
1. Click "Lightning Address" button on main page
2. Verify `/npub` page loads with Trails Coffee branding
3. Enter username in field (e.g., `testuser`)
4. Click outside field to check availability
5. Verify availability status shows (green checkmark or red error)
6. Click "Claim Username (5000 sats)"
7. Verify payment dialog shows with QR code and invoice
8. Pay the invoice from another wallet
9. Verify system detects payment within 5-30 seconds
10. Verify address updates to `testuser@trailscoffee.com`

#### Test 3: Automatic Payment Claiming
1. Share your Lightning address with someone
2. Have them send a payment (e.g., 100 sats)
3. Wait up to 30 seconds
4. Verify notification: "You have X sats on npub.cash"
5. Verify balance automatically updates in wallet
6. Check transaction history for the claimed ecash

#### Test 4: Manual Testing via curl
```bash
# Test server connectivity
curl -s "https://npubcash.trailscoffee.com/api/v1/info" \
  -H "Authorization: Nostr <nip98-token>"

# Expected: {"username":"...","npub":"...","mintUrl":"https://ecash.trailscoffee.com"}
```

## Known Issues

### Issue 1: Server Configuration Required
**Problem**: Lightning address creates successfully but payments don't convert to ecash
**Cause**: npubcash server not configured with correct MINTURL
**Solution**: Set `MINTURL=https://ecash.trailscoffee.com` in server environment

### Issue 2: Payment Delays
**Problem**: Payments take time to appear in wallet
**Cause**: 30-second check interval + backend processing time
**Solution**: This is expected behavior. Consider reducing interval for testing (currently 30s)

### Issue 3: Username Already Claimed
**Problem**: Users can't change their username once claimed
**Cause**: Backend limitation - one username per public key
**Solution**: Users need to use a different wallet/key pair for different usernames

## Configuration Summary

### Frontend Defaults
```typescript
// src/stores/npubcash.ts
npcEnabled: true  // Lightning address ON by default
npcDomain: "trailscoffee.com"  // User-facing domain
baseURL: "https://npubcash.trailscoffee.com"  // API server
```

### Backend Requirements
- **MINTURL**: `https://ecash.trailscoffee.com` (CRITICAL)
- **HOSTNAME**: `https://npubcash.trailscoffee.com`
- **Blink API**: Configured with webhook
- **Database**: PostgreSQL with required tables

## Development Notes

### Why This Branch Was Parked

This branch was created to test and validate the npubcash backend configuration before full integration. The Lightning address feature requires:

1. Properly configured npubcash server (complex setup)
2. Blink API account and webhook integration
3. PostgreSQL database
4. Testing of username claiming flow
5. Validation that ecash conversion works correctly

The branch preserves all this work for future integration once the backend is fully configured and tested.

### Future Work

When resuming this development:

1. **Backend Setup**: Complete npubcash server configuration
2. **Testing**: Validate username claiming and payment flows
3. **UI Polish**: Fix any issues with NpubPage loading
4. **Integration**: Merge automatic claiming into main branch
5. **Documentation**: Add user-facing guide for claiming usernames

## Deployment

### To Deploy This Branch:

```bash
# Switch to this branch
git checkout lightning-address-dev

# Build PWA
cd /home/juli/git/cashu.me
npm run build:pwa

# Serve (testing)
cd dist/pwa
python3 -m http.server 8080 --bind 0.0.0.0

# Or deploy to Hostinger
# Follow HOSTINGER-DEPLOYMENT-GUIDE.md
```

### Backend Deployment:

```bash
# On your server
cd /path/to/npubcash-server

# Create .env file with all required variables
nano .env

# Install dependencies
npm ci

# Build
npm run build

# Start server
npm run start

# Or use PM2 for production
pm2 start npm --name "npubcash-server" -- start
```

## API Documentation

### Authentication
All API endpoints require NIP-98 authentication in the Authorization header:
```
Authorization: Nostr <base64-encoded-nip98-event>
```

### Endpoints

#### GET /api/v1/info
Returns user information including username and mint URL.

#### PUT /api/v1/info/username
Checks username availability or claims username after payment.

#### GET /api/v1/balance
Returns available balance (unclaimed Lightning payments).

#### GET /api/v1/claim
Returns ecash token for available balance.

#### POST /api/v1/paid (Webhook)
Blink webhook endpoint - called when Lightning invoice is paid.

## Security Considerations

1. **NIP-98 Authentication**: All API calls are authenticated with Nostr signatures
2. **Payment Verification**: Username claims require Lightning payment
3. **Rate Limiting**: Consider adding rate limiting on backend
4. **Private Keys**: Wallet seed generates Nostr keys - keep seed secure
5. **Token Storage**: Ecash tokens stored in backend database until claimed

## Support & Troubleshooting

### Common Issues

**Q: Lightning address shows but payments don't appear**
A: Check that npubcash server MINTURL is set to `https://ecash.trailscoffee.com`

**Q: Username availability check fails**
A: Verify npubcash server is running and accessible at `npubcash.trailscoffee.com`

**Q: Payment confirmation takes too long**
A: Check Blink webhook is configured correctly and server is receiving callbacks

**Q: Can't access /npub page**
A: Click the "Lightning Address" button on main wallet page

### Debug Logging

Check browser console for:
```
### starting lightning address check worker
### checking lightning address for new claims
npub.cash balance: X
```

Check server logs for:
```
Webhook received: POST /api/v1/paid
Payment confirmed for user: npub1...
Token created for claim
```

## References

- **npub.cash**: https://github.com/cashubtc/npubcash-server
- **Lightning Address Spec**: https://github.com/andrerfneves/lightning-address
- **NIP-98**: https://github.com/nostr-protocol/nips/blob/master/98.md
- **Cashu Protocol**: https://github.com/cashubtc/nuts
- **Blink API**: https://dev.blink.sv/

## License

Same as parent project (MIT License)

## Author

Trails Coffee Rewards Team

## Last Updated

October 16, 2025




