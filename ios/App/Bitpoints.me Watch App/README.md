# Bitpoints watchOS App scaffold

This folder contains a standalone SwiftUI watchOS app that shows a BitChat-compatible QR payload generated from the new `SharedNostrCore` Swift package.

### Linking the shared package
1. Open the workspace in Xcode and add the local package at `ios/SharedNostrCore`.
2. Add `SharedNostrCore` as a dependency to the watch extension target.

### Creating the watch target
- Add a watchOS app + extension to the existing Xcode project (or create a new watch-only project) and point its sources to this folder.
- Set the app’s bundle ID (defaults to `com.bitpoints.watch`) and enable Keychain sharing if you want to persist keys across reinstalls.

### Build notes
- The QR payload uses the BitChat `bitchat1:` envelope with TLV private message payloads to match the web/iOS helpers.
- The view model auto-generates a secp256k1 keypair on first launch and persists it in Keychain.

