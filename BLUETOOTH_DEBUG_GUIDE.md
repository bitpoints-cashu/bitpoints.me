# Bluetooth Debug Guide

## Overview

The Bluetooth Debug Panel provides real-time monitoring of Bluetooth token transfers to help diagnose issues with send/receive functionality.

## Accessing the Debug Panel

1. Open the app and go to **Settings**
2. Scroll down to the **Bluetooth Mesh** section
3. Click the **"Debug Logs"** button (purple button with bug icon)
4. The debug panel will open in a full-screen dialog

## Understanding the Debug Panel

### Header Information

- **Total Events**: Number of debug events logged
- **Session Duration**: How long the debug session has been running
- **Events/Min**: Rate of events per minute

### Controls

- **Filter**: Filter events by type (Send, Receive, Claim, Error, etc.)
- **Search**: Search through event messages and data
- **Auto-scroll**: Automatically scroll to show newest events
- **Pause/Resume**: Pause auto-scrolling to examine specific events
- **Download**: Export logs as text file for sharing
- **Clear**: Clear all logged events

### Event Types

#### 📤 Send Events

- **When**: Token send attempts
- **Data**: Peer ID, amount, mint URL, token length
- **Example**: `Initiating send: 10 sat to peer abc123`

#### 📥 Receive Events

- **When**: Tokens received from peers
- **Data**: Sender info, amount, token preview
- **Example**: `Token received from peer xyz789`

#### 💰 Claim Events

- **When**: Token claim attempts and results
- **Data**: Message ID, success/failure status
- **Example**: `✅ Token claimed successfully`

#### 🏦 Mint Check Events

- **When**: Mint validation during token processing
- **Data**: Mint URL, known/unknown status
- **Example**: `Checking mint: https://mint.example.com`

#### 👥 Peer Events

- **When**: Peer discovery and connection changes
- **Data**: Peer ID, nickname, connection status
- **Example**: `New peer discovered`

#### ❌ Error Events

- **When**: Failures in send/receive/claim process
- **Data**: Error message, stack trace
- **Example**: `Send failed with error`

## Common Debug Scenarios

### Scenario 1: Token Not Arriving

**Check these events in order:**

1. Look for `📤 Send` events - was the send initiated?
2. Check for `📡 Broadcasting TEXT` or `📤 Sending TEXT to specific peer` in Android logs
3. Look for `📥 Receive` events on the receiving device
4. Check for `🏦 Mint Check` events - is the mint known?
5. Look for `💰 Claim` events - did the claim succeed?

**Common Issues:**

- Send event exists but no Android broadcast log → Native send failed
- Android broadcast log exists but no receive event → Network/peer issue
- Receive event exists but no claim event → Auto-claim disabled or offline
- Claim event shows error → Mint validation or token format issue

### Scenario 2: Auto-Claim Not Working

**Check these events:**

1. Look for `💰 Auto-claiming received token` events
2. Check `🏦 Mint Check` events for mint validation
3. Look for `💰 Claim` events and their success/failure
4. Check for `❌ Error` events with claim failures

**Common Issues:**

- No auto-claim event → Token received while offline
- Mint check shows "unknown" → Mint auto-add may have failed
- Claim shows error → Token may be invalid or already spent

### Scenario 3: Multiple Mints Issue

**Check these events:**

1. Look for `🏦 Mint Check` events showing "unknown" mints
2. Check for `🏦 Mint unknown, auto-adding` events
3. Look for `✅ Mint add success` or `❌ Mint add failed` events
4. Check if claim events follow successful mint adds

**Common Issues:**

- Mint add fails → Receiver can't validate tokens from that mint
- Mint add succeeds but claim still fails → Token format or validation issue

## Reading Log Output

### Event Format

```
[10:23:45.123] 📤 [SEND] Initiating send: 10 sat to peer abc123
[10:23:45.156] 📤 [SEND] Token encoded: cashuBo2Ft... (247 chars)
[10:23:45.189] 📤 [SEND] Mint: https://testnut.cashu.space
[10:23:45.234] 📤 [SEND] Message ID: msg_uuid_123
[10:23:45.267] 📤 [SEND] Calling native sendToken...
[10:23:45.301] 📤 [SEND] Native returned success
```

### Android Native Logs

Look for these patterns in Android logs (via `adb logcat`):

```
BluetoothEcashService: Sending ecash token as TEXT message: 10 sat, token length: 247
BluetoothEcashService: Token preview: cashuBo2Ft...
BluetoothEcashService: Mint: https://testnut.cashu.space
BluetoothEcashService: 📤 Sending TEXT to specific peer: abc123
BluetoothEcashService: ✅ Stored ecash token: 10 sat from sender...
```

## Troubleshooting Steps

### Step 1: Enable Debug Logging

1. Open debug panel
2. Verify events are being logged
3. If no events, check if Bluetooth service is running

### Step 2: Test Basic Send

1. Send a token to a nearby peer
2. Check for complete send flow in logs
3. Verify Android native logs show broadcast

### Step 3: Test Basic Receive

1. Have another device send a token
2. Check for receive and claim events
3. Verify mint validation process

### Step 4: Test Multiple Mints

1. Configure different mints on sender/receiver
2. Send token and watch mint auto-add process
3. Verify claim succeeds after mint add

## Sharing Debug Information

### Export Logs

1. Click the **Download** button in debug panel
2. Choose text format for easy sharing
3. Share the exported file for analysis

### Key Information to Include

- Debug panel export (last 100+ events)
- Android logcat output (if available)
- Description of the issue
- Steps to reproduce
- Device information (Android version, app version)

## Performance Notes

- Debug logging stores last 1000 events
- Logs persist across app restarts
- Export function creates timestamped files
- Auto-scroll can be disabled for better performance

## Advanced Usage

### Filtering Events

- Use type filter to focus on specific event types
- Use search to find specific error messages or peer IDs
- Combine filters for detailed analysis

### Real-time Monitoring

- Keep debug panel open during testing
- Use pause/resume to examine specific time periods
- Monitor event rates to identify performance issues

### Error Analysis

- Look for error events with detailed stack traces
- Check for patterns in failed operations
- Use search to find specific error messages
