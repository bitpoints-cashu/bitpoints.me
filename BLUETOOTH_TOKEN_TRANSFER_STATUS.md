# Bluetooth Token Transfer - Current Status

## ✅ What's Working:

### 1. Transaction History Integration
- **All Bluetooth sends** are saved to transaction history with 📡 icon
- **QR codes available** for every sent token
- Recipients can claim via QR scan even if Bluetooth fails
- **Perfect fallback** for offline transfers

### 2. Peer Discovery
- Devices successfully discover each other over Bluetooth
- Shows peer list with nicknames
- Real-time connection status

### 3. Token Creation & Serialization
- Tokens properly created from wallet proofs
- Serialized to standard Cashu format (cashuA...)
- Transaction history preserves full token string

## ⚠️ Current Limitation:

### Bluetooth Delivery to Trails App Users
The actual Bluetooth mesh transmission is not yet triggering the send operation from the frontend. The transaction history is being created (good!), but the native `sendToken` method needs to be called to actually transmit over Bluetooth.

**Issue**: Frontend send button may not be calling `bluetoothStore.sendToken()` correctly.

## 🔄 Interoperability with Non-Trails Users:

### Current Implementation
Tokens are sent in a custom binary format (`EcashMessage`) that includes:
- Cashu token string
- Amount, unit, mint URL
- Sender identity (npub)
- Memo and delivery status
- Encrypted with Noise protocol

**Result**: Only Trails app users can receive and decode these messages.

### For Universal Compatibility (Future Enhancement)

To send tokens that ANY Bluetooth app can receive (bitchat, etc.), we would need:

1. **Option to send as plain text**:
   ```kotlin
   // Instead of EcashMessage binary format
   val plainTextPacket = BitchatPacket(
       type = MessageType.TEXT.value,
       payload = cashuTokenString.toByteArray()
   )
   ```

2. **Recipient sees**:
   - Plain text message: `cashuBo2FteB5odHRwczovL...`
   - Can copy/paste into any Cashu wallet
   - Works with bitchat, Signal, WhatsApp, etc.

3. **Trade-offs**:
   - ✅ Universal compatibility
   - ✅ Simpler protocol
   - ❌ No automatic claiming
   - ❌ No delivery confirmations
   - ❌ Less metadata (amount, memo)

## 📊 Current Workflow:

### Send Flow (Working)
1. User selects peer and amount
2. Token created and serialized ✅
3. **Added to transaction history** ✅
4. QR code available ✅
5. Bluetooth transmission attempted ⚠️

### Receive Flow (Needs Testing)
1. Bluetooth packet received
2. Decrypted and validated
3. Parsed as EcashMessage
4. Added to unclaimed tokens
5. Notification shown
6. Auto-claim if online

### Fallback Flow (Working Perfectly)
1. Sender shows QR from transaction history
2. Recipient scans QR code
3. Token claimed manually
4. **This works with ANY Cashu wallet** ✅

## 💡 Recommendations:

### Short Term (Current Implementation)
- Continue using transaction history + QR codes as primary method
- Debug the Bluetooth transmission trigger
- This provides best UX for Trails → Trails transfers

### Long Term (For Interoperability)
Add a setting:
- **"Trails Users Only"**: Use encrypted EcashMessage format (current)
- **"Universal/Plaintext"**: Send raw token string for any Bluetooth app

This gives users flexibility based on who they're sending to.

## 🎯 Best Practice for Now:

**For Trails Users:**
- Use "Send to Nearby" feature
- Token saved in history with QR code
- If Bluetooth fails, share QR code

**For Non-Trails Users:**
- Use transaction history QR code
- Or copy token string from history
- Recipient can paste into any Cashu wallet

## Technical Notes:

### Why Transaction History is Important:
Even with working Bluetooth, the transaction history provides:
1. **Audit trail** of all sends
2. **Backup** if Bluetooth fails
3. **QR sharing** option
4. **Proof of payment** for sender
5. **Re-send capability** if needed

This is actually a **better UX** than Bluetooth-only!




