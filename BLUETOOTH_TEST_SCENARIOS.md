# Bluetooth Test Scenarios

## Test Environment Setup

### Prerequisites

- Two Android devices with the app installed
- Both devices have Bluetooth enabled
- Both devices are within 10-30 meters of each other
- Debug logging enabled (open debug panel)

### Test Data

- Test tokens: Use small amounts (1-10 sats) for testing
- Test mints: Use different mints to test multi-mint scenarios
- Test peers: Use different nicknames to identify devices

## Test Scenarios

### Scenario 1: Same Mint - Basic Send/Receive

**Setup:**

- Device A: Configure mint X (e.g., https://testnut.cashu.space)
- Device B: Configure same mint X
- Both devices online

**Steps:**

1. Device A: Send 5 sats to Device B
2. Device B: Verify token received and auto-claimed
3. Check both debug panels for complete flow

**Expected Results:**

- Device A shows: Send → Native success
- Device B shows: Receive → Mint known → Claim success
- Token appears in Device B's balance

**Debug Logs to Check:**

```
Device A:
📤 [SEND] Initiating send: 5 sat to peer abc123
📤 [SEND] Native send successful

Device B:
📥 [RECV] Token received from peer xyz789
🏦 [MINT] Checking mint: https://testnut.cashu.space
🏦 [MINT] Mint known: true
💰 [CLAIM] Auto-claiming received token
💰 [CLAIM] ✅ Token claimed successfully
```

### Scenario 2: Different Mints - Auto-Add Mint

**Setup:**

- Device A: Configure mint X
- Device B: Configure mint Y (different mint)
- Both devices online

**Steps:**

1. Device A: Send 3 sats to Device B
2. Device B: Verify mint auto-add and token claim
3. Check debug logs for mint validation

**Expected Results:**

- Device B auto-adds mint X
- Token claims successfully after mint add
- Both mints now configured on Device B

**Debug Logs to Check:**

```
Device B:
📥 [RECV] Token received from peer xyz789
🏦 [MINT] Checking mint: https://mint.example.com
🏦 [MINT] Mint known: false
🏦 [MINT] Mint unknown, auto-adding
🏦 [MINT] ✅ Mint add success
💰 [CLAIM] Auto-claiming received token
💰 [CLAIM] ✅ Token claimed successfully
```

### Scenario 3: Offline Receive - Delayed Claim

**Setup:**

- Device A: Online, configured with mint X
- Device B: Offline, configured with mint X
- Both devices in Bluetooth range

**Steps:**

1. Device B: Go offline (airplane mode)
2. Device A: Send 2 sats to Device B
3. Device B: Verify token received but not claimed
4. Device B: Go online
5. Device B: Verify token auto-claims

**Expected Results:**

- Token received while offline
- Token appears in unclaimed list
- Auto-claim triggers when online
- Token successfully claimed

**Debug Logs to Check:**

```
Device B (offline):
📥 [RECV] Token received from peer xyz789
💰 [CLAIM] Token received offline, will claim when online

Device B (online):
💰 [CLAIM] Auto-claiming token abc
💰 [CLAIM] ✅ Token claimed successfully
```

### Scenario 4: Multiple Rapid Sends

**Setup:**

- Device A: Configure mint X
- Device B: Configure mint X
- Both devices online

**Steps:**

1. Device A: Send 3 tokens rapidly (1 sat each)
2. Device B: Verify all tokens received and claimed
3. Check for any missed or failed claims

**Expected Results:**

- All 3 tokens received
- All 3 tokens auto-claimed
- No duplicate processing
- Debug logs show sequential processing

**Debug Logs to Check:**

```
Device B:
📥 [RECV] Token received from peer xyz789 (3 times)
💰 [CLAIM] Auto-claiming token abc1
💰 [CLAIM] Auto-claiming token abc2
💰 [CLAIM] Auto-claiming token abc3
💰 [CLAIM] ✅ Token claimed successfully (3 times)
```

### Scenario 5: Large Token - Fragmentation

**Setup:**

- Device A: Configure mint X
- Device B: Configure mint X
- Both devices online
- Create large token (many proofs)

**Steps:**

1. Device A: Send large token (10+ proofs)
2. Device B: Verify token received and claimed
3. Check Android logs for fragmentation

**Expected Results:**

- Token sent successfully despite size
- Android logs show fragmentation if needed
- Token received and claimed successfully

**Debug Logs to Check:**

```
Android logs:
BluetoothEcashService: Sending ecash token as TEXT message: 50 sat, token length: 2048
BluetoothEcashService: Fragmenting packet into 3 fragments
BluetoothEcashService: ✅ Stored ecash token: 50 sat from sender...
```

### Scenario 6: Invalid Token - Error Handling

**Setup:**

- Device A: Configure mint X
- Device B: Configure mint X
- Both devices online

**Steps:**

1. Device A: Send malformed/invalid token
2. Device B: Verify error handling
3. Check debug logs for error details

**Expected Results:**

- Token received but claim fails
- Error logged with details
- Token remains in unclaimed list
- User can retry manually

**Debug Logs to Check:**

```
Device B:
📥 [RECV] Token received from peer xyz789
💰 [CLAIM] Auto-claiming received token
💰 [CLAIM] Attempting to decode token
❌ [ERROR] Token decode failed - invalid format
💰 [CLAIM] Auto-claim failed, showing error notification
```

### Scenario 7: Already Spent Token

**Setup:**

- Device A: Configure mint X
- Device B: Configure mint X
- Both devices online

**Steps:**

1. Device A: Send token to Device B
2. Device B: Claim token successfully
3. Device A: Send same token again
4. Device B: Verify already spent handling

**Expected Results:**

- Second send shows "already spent" error
- Token removed from unclaimed list
- No error notification shown
- Debug logs show handling

**Debug Logs to Check:**

```
Device B:
📥 [RECV] Token received from peer xyz789
💰 [CLAIM] Auto-claiming received token
💰 [CLAIM] Token already spent, removing from unclaimed list
```

### Scenario 8: Peer Discovery

**Setup:**

- Device A: App open, Bluetooth active
- Device B: App open, Bluetooth active
- Both devices in range

**Steps:**

1. Open both apps
2. Wait for peer discovery
3. Verify peers appear in nearby list
4. Check debug logs for discovery events

**Expected Results:**

- Peers discovered within 10 seconds
- Peers show correct nicknames
- Debug logs show discovery events

**Debug Logs to Check:**

```
Device A:
👥 [PEER] New peer discovered
👥 [PEER] Peer info updated

Device B:
👥 [PEER] New peer discovered
👥 [PEER] Peer info updated
```

## Test Checklist

### Pre-Test Setup

- [ ] Both devices have app installed
- [ ] Bluetooth enabled on both devices
- [ ] Debug panel open on both devices
- [ ] Test mints configured
- [ ] Devices within range (10-30m)

### Basic Functionality

- [ ] Peer discovery works
- [ ] Send to specific peer works
- [ ] Send broadcast works
- [ ] Receive and auto-claim works
- [ ] Manual claim works

### Multi-Mint Scenarios

- [ ] Same mint works
- [ ] Different mint auto-adds
- [ ] Mint add failure handled
- [ ] Unknown mint error shown

### Error Handling

- [ ] Invalid token handled
- [ ] Already spent token handled
- [ ] Network errors handled
- [ ] Offline receive works

### Performance

- [ ] Rapid sends work
- [ ] Large tokens work
- [ ] No memory leaks
- [ ] Debug logs don't slow app

### Edge Cases

- [ ] App background/foreground
- [ ] Bluetooth toggle during send
- [ ] Device sleep during receive
- [ ] Multiple app instances

## Common Issues and Solutions

### Issue: Peers Not Appearing

**Check:**

- Bluetooth permissions granted
- Location permission granted
- Devices within range
- App not in background

**Debug:**

- Look for peer discovery events
- Check Android logs for scan results
- Verify Bluetooth service running

### Issue: Send Fails

**Check:**

- Peer still connected
- Bluetooth still active
- Token valid format
- Native send logs

**Debug:**

- Look for send events in debug panel
- Check Android logs for broadcast
- Verify token encoding

### Issue: Receive Fails

**Check:**

- Token format valid
- Mint reachable
- Auto-claim enabled
- Network connection

**Debug:**

- Look for receive events
- Check mint validation logs
- Verify claim process

### Issue: Auto-Claim Fails

**Check:**

- Mint known or auto-addable
- Token not already spent
- Network connection
- Token format valid

**Debug:**

- Look for mint check events
- Check claim error details
- Verify token decode

## Reporting Issues

When reporting Bluetooth issues, include:

1. **Debug Panel Export**: Last 100+ events from both devices
2. **Android Logs**: `adb logcat` output during the issue
3. **Test Scenario**: Which scenario failed
4. **Steps to Reproduce**: Exact steps taken
5. **Device Info**: Android version, app version
6. **Network Info**: WiFi/cellular status
7. **Mint Info**: Which mints configured

## Performance Benchmarks

### Expected Performance

- **Peer Discovery**: 5-10 seconds
- **Token Send**: 1-3 seconds
- **Token Receive**: 1-2 seconds
- **Auto-Claim**: 2-5 seconds
- **Mint Add**: 3-10 seconds

### Memory Usage

- **Debug Logs**: ~1MB for 1000 events
- **Unclaimed Tokens**: ~10KB per token
- **Peer List**: ~1KB per peer

### Battery Impact

- **Always-On Mode**: Higher battery usage
- **Debug Logging**: Minimal impact
- **Bluetooth Scanning**: Moderate impact
