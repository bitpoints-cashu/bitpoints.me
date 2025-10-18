# Test Token Helper for Bluetooth Testing

## Problem

You can't test Bluetooth token transfers without having tokens first!

## Quick Solution

### Option 1: Use Testnut Mint (No Setup Required)

1. Open https://testnut.cashu.space in a browser
2. Click "Mint" → Generate 100 sats (free testnet)
3. Copy the token
4. Paste into your app's "Receive" tab
5. Now you have tokens to send via Bluetooth!

### Option 2: Use wallet.cashu.me

1. Go to https://wallet.cashu.me
2. Add Testnut mint: `https://testnut.cashu.space`
3. Request test tokens (free)
4. Copy token
5. Paste in your app

### Option 3: Use Another Device

If you have the app on Device 2:
1. Get tokens on Device 2 first (using above methods)
2. Then send from Device 2 → Device 1 via Bluetooth
3. Now Device 1 has tokens to send back!

---

## Current Testing Workflow

```
Step 1: Get Tokens
├─ Use testnet mint (testnut.cashu.space)
├─ Request 100 test sats (free)
└─ Receive in wallet

Step 2: Verify Balance
├─ Check wallet shows balance > 0
└─ Wallet now has keysets

Step 3: Test Bluetooth
├─ Device 1: Has tokens (sender)
├─ Device 2: Empty (receiver)
├─ Send 10 sats via "Send to Nearby"
└─ Device 2 receives notification

Step 4: Test Round-Trip
├─ Device 2 now has 10 sats
├─ Send 5 sats back to Device 1
└─ Verify mesh networking works both ways
```

---

## For Production Testing

If you're testing with real Trails Coffee tokens:

1. **Admin generates tokens:**
   ```
   # In Trails Coffee admin panel
   - Create token: 100 sats
   - Copy token string
   ```

2. **Receive on device:**
   - Open app → Receive tab
   - Paste token
   - Confirm receipt

3. **Now test Bluetooth:**
   - Has balance ✓
   - Has keysets ✓
   - Can send via Bluetooth ✓

---

## Quick Commands

### Check if wallet has tokens
```bash
adb logcat -d | grep -i "balance\|sats\|amount" | grep Capacitor/Console | tail -5
```

### Monitor token receive
```bash
adb logcat | grep -E "receive.*token|claimed|keyset.*found"
```

### Check Bluetooth status
```bash
adb logcat | grep -E "BluetoothMesh|peer ID|nearby"
```

---

## Troubleshooting

### "No keysets found" Error
**Cause:** Wallet is empty
**Fix:** Receive tokens first (see options above)

### "Cannot connect to mint"
**Cause:** Network issue or mint down
**Fix:** Try testnut.cashu.space (reliable testnet)

### "Token already claimed"
**Cause:** Token was used before
**Fix:** Generate new token

---

## Recommended Test Flow

For testing Bluetooth WITHOUT needing real money:

1. **Both devices install app** ✓
2. **Device 1: Get testnet tokens**
   - Use testnut.cashu.space
   - Mint 100 sats (free)
   - Paste in app

3. **Device 1 → Device 2: Send 50 sats via Bluetooth**
   - Tests mesh networking
   - Tests token creation
   - Tests peer discovery

4. **Device 2 → Device 1: Send 25 sats back**
   - Tests bidirectional
   - Tests mesh relay
   - Verifies end-to-end

---

## Links

- **Testnut (Testnet):** https://testnut.cashu.space
- **Cashu Wallet:** https://wallet.cashu.me
- **Trails Coffee:** https://ecash.trailscoffee.com
- **Cashu Docs:** https://docs.cashu.space

---

## Next Steps

1. ✅ Get test tokens (use testnut.cashu.space - fastest)
2. ✅ Verify balance appears in app
3. ✅ Enable Bluetooth on both devices
4. ✅ Test "Send to Nearby"
5. ✅ Verify peer discovery
6. ✅ Send token and check receipt

Once you have tokens, the Bluetooth mesh networking is ready to test! 🚀




