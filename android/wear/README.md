# Bitpoints Wear OS Implementation

This directory contains the Wear OS standalone implementation of the Bitpoints wallet, allowing users to send and receive Cashu ecash tokens directly from their smartwatch without requiring a paired phone.

## Features

### ✅ Implemented
- **Standalone Operation**: Runs independently without phone companion
- **Bluetooth Mesh Networking**: Send/receive tokens via Bluetooth to nearby devices
- **Ambient Mode Support**: Optimized display for always-on watch faces
- **Battery Optimization**: Intelligent power management for watch battery life
- **Simplified UI**: Watch-optimized interface with large touch targets
- **Nostr Integration**: Auto-claim tokens received via Nostr messages
- **Complications Support**: Display balance on watch face

### 🔄 Core Functionality
- **View Balance**: Check current Cashu token balance
- **Send Tokens**: Transfer tokens to nearby devices via Bluetooth mesh
- **Receive Tokens**: Accept tokens via QR code or NFC
- **Transaction History**: View recent transactions (simplified for watch)
- **Peer Discovery**: Find and connect to nearby Bitpoints users

## Architecture

### Wear OS Module Structure
```
android/wear/
├── build.gradle                    # Wear OS dependencies and configuration
├── src/main/
│   ├── AndroidManifest.xml         # Standalone Wear OS manifest
│   ├── java/me/bitpoints/wear/
│   │   ├── WearMainActivity.kt      # Main Compose UI activity
│   │   ├── WearWebViewManager.kt    # WebView bridge for Vue.js UI
│   │   ├── WearBluetoothEcashPlugin.kt  # Capacitor plugin for BT mesh
│   │   ├── services/
│   │   │   ├── WearAlwaysOnService.kt     # Background service
│   │   │   ├── WearComplicationsService.kt  # Watch face complications
│   │   │   └── WearPowerManager.kt        # Battery optimization
│   │   ├── mesh/                   # Bluetooth mesh networking
│   │   ├── noise/                  # Noise Protocol encryption
│   │   ├── crypto/                 # Cryptographic functions
│   │   ├── model/                  # Data models
│   │   ├── protocol/               # Binary protocol handling
│   │   └── sync/                   # Gossip sync protocol
│   └── res/
│       ├── values/
│       │   ├── strings.xml         # Wear OS strings
│       │   └── dimens.xml          # Watch-specific dimensions
│       └── xml/
│           ├── file_paths.xml      # File provider paths
│           └── watch_face_info.xml # Complications configuration
└── capacitor.build.gradle          # Capacitor integration
```

### Web UI Structure
```
src/
├── assets/css/
│   └── wear-os.css                 # Watch-optimized responsive styles
├── pages/wear/
│   ├── WearWalletPage.vue          # Main wallet view
│   ├── WearSendPage.vue            # Send tokens interface
│   ├── WearReceivePage.vue         # Receive tokens interface
│   └── WearHistoryPage.vue         # Transaction history
├── layouts/
│   └── WearLayout.vue              # Wear OS layout wrapper
└── router/
    └── wear-routes.js              # Watch-specific routing
```

## Build Instructions

### Prerequisites
- Android Studio with Wear OS emulator
- Node.js 16+ and npm
- Java 17+
- Wear OS device (optional, for testing)

### Build Commands

1. **Build Web Assets for Wear OS**:
   ```bash
   npm run build:wear
   ```

2. **Sync Capacitor**:
   ```bash
   npm run sync:wear
   ```

3. **Build Wear OS APK**:
   ```bash
   cd android/wear
   ./gradlew assembleDebug
   ```

4. **Install on Device**:
   ```bash
   adb -s <watch_device> install app/build/outputs/apk/debug/app-debug.apk
   ```

### Development Workflow

1. **Start Development Server**:
   ```bash
   npm run dev
   ```

2. **Open Wear OS Project**:
   ```bash
   npm run open:wear
   ```

3. **Run on Emulator**:
   ```bash
   npm run run:wear
   ```

## Configuration

### Wear OS Specific Settings

The app is configured for standalone operation with these key settings:

- **Standalone Mode**: `com.google.android.wearable.standalone = true`
- **Minimum SDK**: API 30 (Wear OS 3.0+)
- **Target SDK**: Latest Android API
- **Permissions**: Bluetooth, Internet, NFC, Notifications

### Battery Optimization

The app includes intelligent battery management:

- **Adaptive Scanning**: Adjusts Bluetooth scan intervals based on battery level
- **Ambient Mode**: Reduces activity when watch enters ambient mode
- **Power Management**: Requests battery optimization exemptions
- **Wake Lock Management**: Minimal wake lock usage

### UI Adaptations

Watch-specific UI optimizations:

- **Touch Targets**: Minimum 48dp for finger interaction
- **Font Sizes**: Optimized for small screens (12-18sp)
- **Navigation**: Swipe-based navigation instead of buttons
- **Ambient Mode**: Simplified display for always-on mode

## Testing

### Emulator Testing
1. Create Wear OS emulator (API 30+)
2. Install APK: `adb install app-debug.apk`
3. Test core functionality: balance, send, receive
4. Test ambient mode transitions
5. Test battery optimization

### Physical Device Testing
1. Enable Developer Options on watch
2. Enable USB Debugging
3. Install APK via ADB
4. Test Bluetooth mesh with phone app
5. Test battery life over 12+ hours

### Test Scenarios
- ✅ App launches and displays balance
- ✅ Bluetooth mesh peer discovery
- ✅ Send tokens to nearby device
- ✅ Receive tokens via QR code
- ✅ Ambient mode transitions
- ✅ Battery optimization requests
- ✅ Complications display balance

## Limitations

### Hardware Constraints
- **Small Screen**: Simplified UI compared to phone app
- **Limited Battery**: Aggressive power management required
- **No Camera**: QR code scanning limited (NFC preferred)
- **Lower CPU/RAM**: Avoid heavy computations

### Feature Limitations
- **Single Mint**: Default mint only (Trails Coffee)
- **Simplified History**: Last 10 transactions only
- **No Lightning Invoices**: Receive only, no invoice creation
- **Minimal Settings**: Basic settings only

### Platform Limitations
- **Wear OS 3.0+**: Requires modern Wear OS devices
- **Bluetooth Range**: Limited to ~10m for mesh networking
- **Internet Dependency**: Requires internet for Nostr/mint access

## Troubleshooting

### Common Issues

1. **Build Errors**:
   - Ensure Wear OS dependencies are properly configured
   - Check Android SDK versions match requirements
   - Verify Capacitor configuration

2. **Bluetooth Issues**:
   - Check Bluetooth permissions
   - Verify device supports BLE
   - Test with different Wear OS devices

3. **Battery Drain**:
   - Check battery optimization settings
   - Monitor Bluetooth scan intervals
   - Test ambient mode functionality

4. **UI Issues**:
   - Verify CSS responsive breakpoints
   - Test on different screen sizes
   - Check touch target sizes

### Debug Commands

```bash
# Monitor logs
adb logcat | grep "BitpointsWear"

# Check Bluetooth status
adb shell dumpsys bluetooth_manager

# Monitor battery usage
adb shell dumpsys batterystats

# Test ambient mode
adb shell am broadcast -a android.intent.action.SCREEN_OFF
```

## Future Enhancements

### Planned Features
- **Native Compose UI**: Replace WebView with native Compose
- **Advanced Complications**: More watch face integration
- **Voice Commands**: Voice-activated token transfers
- **Gesture Controls**: Rotary input for navigation
- **Offline Mode**: Full offline operation capability

### Performance Optimizations
- **Bluetooth Mesh Optimization**: Reduce power consumption
- **UI Rendering**: Improve Compose performance
- **Memory Management**: Optimize for watch constraints
- **Background Processing**: Better background task handling

## Contributing

When contributing to the Wear OS implementation:

1. **Test on Physical Device**: Always test on real Wear OS hardware
2. **Battery Impact**: Consider battery life implications
3. **UI Guidelines**: Follow Wear OS design guidelines
4. **Performance**: Optimize for watch hardware constraints
5. **Accessibility**: Ensure accessibility on small screens

## Support

For Wear OS specific issues:
- Check Wear OS documentation
- Test on multiple device types
- Monitor battery usage patterns
- Verify Bluetooth compatibility

---

**Note**: This Wear OS implementation is designed for standalone operation and provides core wallet functionality optimized for smartwatch constraints. For full features, use the main Android app.

