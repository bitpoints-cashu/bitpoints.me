# Bitpoints Native iOS App

This is a native iOS app that wraps the Bitpoints.me web application in a WKWebView while providing native Bluetooth mesh networking capabilities.

## Architecture

- **Native iOS**: Swift/SwiftUI for the app shell and Bluetooth functionality
- **Web App**: Vue/Quasar application running in WKWebView for Cashu operations
- **Bridge**: JavaScript ↔ Swift communication via WKScriptMessageHandler

## Features

- ✅ Native Bluetooth mesh networking (discover, send, receive tokens)
- ✅ Full Cashu wallet functionality (mint, melt, swap, Nostr integration)
- ✅ Web UI with native performance
- ✅ Background Bluetooth operation
- ✅ Cross-platform compatibility (Android/PWA unaffected)

## Project Structure

```
ios-native/
├── BitpointsNative.xcodeproj/          # Xcode project
└── BitpointsNative/
    ├── App/                            # SwiftUI app files
    │   ├── BitpointsNativeApp.swift    # App entry point
    │   ├── ContentView.swift           # Main container view
    │   └── WebViewContainer.swift      # WKWebView wrapper
    ├── Services/                       # Bluetooth services (copied from ios/App/App/)
    │   ├── BLEService.swift
    │   ├── BluetoothEcashService.swift
    │   └── TransportConfig.swift
    ├── Bridge/                         # JavaScript ↔ Swift bridge
    │   ├── WebViewBridge.swift         # Message handler
    │   └── BluetoothBridge.swift       # Bluetooth event forwarding
    ├── Resources/
    │   └── webapp/                     # Bundled web app (dist/spa/)
    └── Info.plist                      # App permissions and config
```

## Building and Running

### Prerequisites

- Xcode 15.0+
- iOS 15.0+ target device or simulator
- Built web app (`npm run build`)

### Build Steps

1. **Build the web app**:
   ```bash
   npm run build
   ```

2. **Copy web app to native project**:
   ```bash
   cp -r dist/spa/* ios-native/BitpointsNative/Resources/webapp/
   ```

3. **Open in Xcode**:
   ```bash
   open ios-native/BitpointsNative.xcodeproj
   ```

4. **Build and run**:
   - Select target device/simulator
   - Press Cmd+R to build and run

### Automatic Build Script

Add this as a "Run Script Phase" in Xcode Build Phases:

```bash
# Build web app if not already built
if [ ! -d "$SRCROOT/../../dist/spa" ]; then
  cd "$SRCROOT/../.."
  npm run build
fi

# Copy web app to Resources
rsync -av --delete "$SRCROOT/../../dist/spa/" "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/webapp/"
```

## How It Works

### JavaScript Bridge Detection

The web app automatically detects if it's running in the native iOS app:

```typescript
const isNativeIOS = Capacitor.getPlatform() === 'ios' && 
                    typeof window.webkit?.messageHandlers?.bluetoothBridge !== 'undefined';
```

### Bluetooth Operations

When running in native iOS, Bluetooth operations use the WebKit message bridge:

```typescript
// JavaScript calls native Swift
window.webkit.messageHandlers.bluetoothBridge.postMessage({
  action: 'startBluetoothService',
  callbackId: 'unique-id'
});

// Native Swift responds via custom events
window.addEventListener('bluetooth_callback_unique-id', (event) => {
  // Handle response
});
```

### Event Flow

1. **Web App** → `BluetoothEcash.startService()` 
2. **JavaScript Bridge** → `window.webkit.messageHandlers.bluetoothBridge.postMessage()`
3. **Swift WebViewBridge** → `userContentController(_:didReceive:)`
4. **Swift BluetoothBridge** → `bluetoothService.startService()`
5. **Native Bluetooth** → CoreBluetooth operations
6. **Swift BluetoothBridge** → `sendToWebView(event:data:)`
7. **JavaScript Bridge** → `window.dispatchEvent(new CustomEvent())`
8. **Web App** → Event listeners receive updates

## Permissions

The app requires these permissions in `Info.plist`:

- `NSBluetoothAlwaysUsageDescription`: Bluetooth mesh networking
- `NSBluetoothPeripheralUsageDescription`: Bluetooth advertising
- `NSLocalNetworkUsageDescription`: Local peer discovery
- `NSBonjourServices`: Service discovery
- `UIBackgroundModes`: Background Bluetooth operation

## Testing

### Manual Testing Checklist

- [ ] App launches and loads web UI
- [ ] Bluetooth permissions prompt appears
- [ ] Bluetooth service starts successfully
- [ ] Can discover nearby peers
- [ ] Can send tokens via Bluetooth
- [ ] Can receive tokens via Bluetooth
- [ ] Web UI updates when Bluetooth events occur
- [ ] All Cashu operations work (mint, melt, swap)
- [ ] Nostr integration works
- [ ] App works in background

### Debug Logging

Look for these log patterns:

- `🔵 [BluetoothEcash] Platform: ios Native iOS: true` - Bridge detection
- `🔵 Received message from JavaScript: bluetoothBridge` - Bridge communication
- `🔵 Bluetooth state updated: poweredOn` - Bluetooth status
- `🔵 Discovered peer: peer-123` - Peer discovery

## Troubleshooting

### Web App Not Loading

- Ensure `dist/spa/` files are copied to `Resources/webapp/`
- Check that `index.html` exists in the bundle
- Verify WKWebView configuration allows local file access

### Bluetooth Not Working

- Check device Bluetooth is enabled
- Verify permissions are granted
- Look for CoreBluetooth delegate method calls in logs
- Ensure `BluetoothEcashServiceDelegate` is properly connected

### Bridge Communication Issues

- Verify `window.webkit.messageHandlers.bluetoothBridge` exists
- Check that message handler is registered in WKWebView configuration
- Look for JavaScript errors in WebView console

## Differences from Capacitor App

| Feature | Capacitor App | Native App |
|---------|---------------|------------|
| Bluetooth | Plugin-based | Native CoreBluetooth |
| Performance | Hybrid overhead | Native performance |
| Background | Limited | Full background support |
| Permissions | Capacitor handling | Direct iOS permissions |
| Bundle ID | `me.bitpoints.wallet` | `me.bitpoints.native` |
| Updates | Capacitor sync | Manual web app copy |

## Future Enhancements

- [ ] Automatic web app updates
- [ ] Push notifications for received tokens
- [ ] Native QR code scanning
- [ ] Apple Watch companion app
- [ ] Widget for quick balance check
- [ ] Siri Shortcuts integration

## Notes

- Keep the Capacitor iOS app (`ios/App/`) as backup
- This native app is completely separate from the Capacitor project
- Android and PWA apps are unaffected by this implementation
- The web app maintains full compatibility across all platforms
