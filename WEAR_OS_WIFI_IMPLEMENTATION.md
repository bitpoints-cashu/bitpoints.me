# Wear OS WiFi-Based Token Transfer Implementation Summary

## Completed: Phase 1 - Core Infrastructure

### Files Created

1. **android/wear/src/main/java/me/bitpoints/wear/cashu/CashuModels.kt**

   - Data classes for Cashu protocol (Proof, Token, MintQuoteResponse, MeltQuoteResponse)
   - TokenEncoder utility for encoding/decoding cashuA tokens
   - Token validation and amount calculation

2. **android/wear/src/main/java/me/bitpoints/wear/cashu/CashuMintClient.kt**

   - HTTP client for Cashu mint API operations
   - Methods: requestMintQuote, checkMintQuote, mintTokens, requestMeltQuote, meltTokens
   - Error handling and retry logic
   - OkHttp-based implementation with 30s timeouts

3. **android/wear/src/main/java/me/bitpoints/wear/crypto/SeedManager.kt**

   - BIP39 mnemonic generation and management
   - Secure storage using EncryptedSharedPreferences
   - Wallet ID generation for watch identification
   - Mnemonic validation

4. **android/wear/src/main/java/me/bitpoints/wear/network/TokenTransferService.kt**

   - HTTP POST-based token sending
   - Network availability checking
   - Retry logic with exponential backoff (max 3 attempts)
   - JSON request/response handling

5. **android/wear/src/main/java/me/bitpoints/wear/network/TokenReceiveService.kt**

   - HTTP polling for incoming tokens
   - Token parsing and validation
   - Acknowledgment system for received tokens

6. **android/wear/src/main/java/me/bitpoints/wear/network/PairingService.kt**
   - QR code generation using ZXing
   - Contact management (save/load/delete)
   - Pairing protocol with bitpoints:// URI scheme
   - Receive endpoint configuration

### Files Enhanced

7. **android/wear/build.gradle**

   - Added OkHttp 4.12.0 for HTTP calls
   - Added ZXing 3.5.2 for QR codes
   - Added WorkManager 2.9.0 for background tasks
   - Added kotlin-bip39 1.0.7 for mnemonic generation

8. **android/wear/src/main/java/me/bitpoints/wear/WearWalletStore.kt**
   - Integrated SeedManager for mnemonic handling
   - Added mint client integration
   - Methods: sendTokenViaHttp, receiveTokenFromString, pollForIncomingTokens
   - Methods: createInvoice, checkAndClaimInvoice
   - Mint URL configuration (default: https://ecash.trailscoffee.com)

## Current Capabilities

### Implemented ✅

- BIP39 mnemonic generation and secure storage
- HTTP POST token sending to endpoints
- HTTP GET/POST token receiving from endpoints
- QR code generation for pairing
- Contact management
- Mint API client (quote requests, token minting/melting)
- Network availability checking
- Token encoding/decoding (cashuA format)
- Wallet ID generation
- Transaction logging

### In Demo Mode 🚧

- Token operations currently use demo balance
- Real Cashu proof generation/management pending
- Cryptographic operations (blinding/unblinding) pending

## Next Steps (Phase 2-4)

### UI Integration

- [ ] Update Send screen with HTTP endpoint input
- [ ] Add QR code display in Receive screen
- [ ] Add manual token input field
- [ ] Create Invoice screen for Lightning
- [ ] Add Settings screen for mint URL config
- [ ] Show wallet seed phrase (backup)

### Real Token Operations

- [ ] Implement actual Cashu proof storage
- [ ] Integrate cryptographic blinding/unblinding
- [ ] Use real proofs instead of demo balance
- [ ] Implement proof selection for sending
- [ ] Add change handling for transactions

### Backend/Server

- [ ] Deploy simple token relay server
- [ ] Or integrate with npub.cash service
- [ ] Implement token queue/acknowledgment system

## Technical Architecture

### Token Flow - Sending

1. User inputs recipient endpoint URL
2. App selects proofs from balance
3. TokenEncoder creates cashuA token string
4. TokenTransferService sends via HTTP POST
5. Balance updated locally
6. Transaction recorded

### Token Flow - Receiving

1. App polls receive endpoint periodically
2. TokenReceiveService fetches pending tokens
3. TokenEncoder decodes cashuA string
4. Balance updated locally
5. Transaction recorded
6. Optional: Acknowledge receipt to server

### Security

- Mnemonic stored in EncryptedSharedPreferences (AES-256-GCM)
- Tokens are bearer instruments (self-contained)
- HTTPS enforced for all network operations
- No private keys transmitted over network

## Testing

### Manual Testing Steps

1. Launch app on watch
2. Go to Status screen to verify WiFi connected
3. Note wallet ID from logs
4. Create a simple HTTP server to receive tokens
5. Test send/receive flow

### Dependencies Installed

```gradle
implementation "com.squareup.okhttp3:okhttp:4.12.0"
implementation "androidx.work:work-runtime-ktx:2.9.0"
implementation "com.google.zxing:core:3.5.2"
implementation "cash.z.ecc.android:kotlin-bip39:1.0.7"
implementation "com.google.code.gson:gson:2.10.1"
implementation "org.bouncycastle:bcprov-jdk18on:1.77"
implementation "androidx.security:security-crypto:1.1.0-alpha06"
```

## Known Limitations

1. Currently using demo balance instead of real Cashu proofs
2. Cryptographic operations (blinding/unblinding) not yet implemented
3. UI still shows basic screens - needs HTTP endpoint inputs
4. No background service for automatic token polling yet
5. Server-side component needs to be deployed

## API Endpoints

### Mint Server (Cashu)

- POST /v1/mint/quote/bolt11 - Request mint quote
- GET /v1/mint/quote/bolt11/{quote_id} - Check quote status
- POST /v1/mint/bolt11 - Mint tokens
- POST /v1/melt/quote/bolt11 - Request melt quote
- POST /v1/melt/bolt11 - Melt tokens

### Token Transfer (Custom)

- POST {endpoint}/send - Send token to recipient
- GET {endpoint}/receive?id={wallet_id} - Poll for incoming tokens
- POST {endpoint}/{token_id}/ack - Acknowledge receipt

## Future Enhancements

- Background WorkManager for automatic polling
- Push notifications for incoming tokens
- QR code scanning (camera not available on most watches)
- NFC tap-to-pay support
- Watch face complications showing balance
- Multi-mint support
- Token history with mint details
