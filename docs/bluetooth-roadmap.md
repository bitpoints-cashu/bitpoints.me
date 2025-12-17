# Bluetooth Mesh Roadmap (Bitpoints iOS)

## Current status
- Capacitor plugin is registered (`BluetoothEcash`) with native stubs; Bluetooth is **off by default** via `settings.bluetoothEnabled`.
- Nostr/BitChat interop is active: gift-wrapped `bitchat1:` packets are sent/parsed when `bitchatInteropEnabled` is on.
- Build/test pipeline is green (`npm run build`, vitest TLV roundtrip).

## What’s needed to complete native BLE
1) Wire native BitChat stack
   - Finish `BluetoothEcash.swift` to use the copied BitChat classes (`BLEService`, `MessageRouter`, `NoiseEncryptionService`, `SecureIdentityStateManager`, etc.).
   - Implement delegate callbacks to emit JS events (`peerDiscovered`, `peerLost`, `ecashReceived`, `tokenSent`, `tokenDelivered`, favorite events).
   - Map JS methods to native: `startService/stopService`, `isBluetoothEnabled`, `requestPermissions`, `getAvailablePeers`, `getUnclaimedTokens`, `markTokenClaimed`, `sendToken`, `sendTextMessage`.
2) Validate iOS project wiring
   - Ensure plugin sources are in target “Compile Sources” (already present).
   - Entitlements file `ios/App/App/App.entitlements` is set in build settings; Info.plist has Bluetooth usage descriptions and background modes.
   - Keep `BluetoothEcashPlugin.m` for Capacitor registration.
3) JS side
   - Flip `settings.bluetoothEnabled` to true when ready to test.
   - Keep `src/plugins/bluetooth-ecash.ts` as the single Capacitor entry; no WebKit bridge needed.
4) QA plan
   - Device-only (simulator lacks peripheral support).
   - Start/stop service, discover peers, send/receive tokens and text; verify event stream.
   - Check background modes and always-on path on iOS; measure battery impact.

## How to resume work
- Enable mesh: toggle `Enable Bluetooth mesh (beta)` in Advanced Features, rebuild, and `npx cap copy ios`.
- Open `ios/App/App.xcworkspace`, clean build folder, run on device.
- Iterate native `BluetoothEcash.swift` and BitChat classes to replace stubs with real BLEService calls.
