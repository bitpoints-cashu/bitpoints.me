# iOS Bluetooth Plugin Debugging Guide

## 🚨 **Current Issue: Bluetooth Plugin Not Loading**

The Bluetooth plugin is implemented but not being loaded by Capacitor, causing "failed to start bluetooth" errors.

## 🔍 **Problem Analysis**

### **What Works**
- ✅ Plugin code is properly implemented
- ✅ Plugin is registered in `capacitor.config.ts`
- ✅ Plugin files are included in iOS build
- ✅ App builds and launches successfully

### **What Doesn't Work**
- ❌ Plugin `load()` method never called
- ❌ No plugin initialization logs
- ❌ Frontend calls to `BluetoothEcash.startService()` fail
- ❌ "Failed to start bluetooth service" error

## 🛠 **Debugging Steps**

### **Step 1: Verify Plugin Registration**

Check if the plugin is properly registered in Capacitor:

```bash
# Check Capacitor config
cat ios/App/App/capacitor.config.json

# Should show:
{
  "ios": {
    "includePlugins": [
      "BluetoothEcash",
      "Camera"
    ]
  }
}
```

### **Step 2: Check Plugin Class Name**

The plugin class must follow Capacitor naming conventions:

```swift
// Current implementation in BluetoothEcashPlugin.swift
@objc(BluetoothEcashPlugin)
public class BluetoothEcashPlugin: CAPPlugin {
    // ...
}
```

**Potential Issue**: Capacitor might expect the class name to match the plugin name exactly.

### **Step 3: Verify Plugin Method Registration**

Check if plugin methods are properly exposed:

```swift
// Current methods in BluetoothEcashPlugin.swift
@objc func startService(_ call: CAPPluginCall) { ... }
@objc func stopService(_ call: CAPPluginCall) { ... }
@objc func sendToken(_ call: CAPPluginCall) { ... }
@objc func receiveToken(_ call: CAPPluginCall) { ... }
```

### **Step 4: Check Capacitor Version Compatibility**

Current versions:
- `@capacitor/core`: 6.2.0
- `@capacitor/ios`: 6.0.0

**Potential Issue**: Version mismatch might cause plugin loading issues.

## 🔧 **Potential Solutions**

### **Solution 1: Fix Plugin Class Name**

Try renaming the plugin class to match Capacitor expectations:

```swift
// Option A: Remove @objc annotation
public class BluetoothEcashPlugin: CAPPlugin {
    // ...
}

// Option B: Use different class name
@objc(BluetoothEcash)
public class BluetoothEcash: CAPPlugin {
    // ...
}
```

### **Solution 2: Check Plugin Registration Method**

Capacitor might require explicit plugin registration. Check if we need to register the plugin in `AppDelegate.swift`:

```swift
// In AppDelegate.swift
import Capacitor

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Register custom plugins
    Capacitor.registerPlugin(BluetoothEcashPlugin.self)
    return true
}
```

### **Solution 3: Update Capacitor Versions**

Fix version mismatch:

```bash
# Update to matching versions
npm install @capacitor/core@6.0.0 @capacitor/ios@6.0.0

# Or update to latest
npm install @capacitor/core@latest @capacitor/ios@latest
```

### **Solution 4: Check Plugin File Structure**

Ensure plugin files are in the correct location:

```
ios/App/App/Plugins/BluetoothEcashPlugin/
└── BluetoothEcashPlugin.swift
```

Capacitor might expect a different file structure or naming convention.

## 🧪 **Testing Approach**

### **Test 1: Add Plugin Registration Logging**

Add logging to `AppDelegate.swift` to see if plugins are being loaded:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    print("🚀 AppDelegate: Application did finish launching")
    
    // Check if Capacitor is loading plugins
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        print("🔍 Checking loaded plugins...")
        // Add plugin checking code here
    }
    
    return true
}
```

### **Test 2: Verify Frontend Plugin Access**

Check if the frontend can access the plugin:

```javascript
// In browser console or frontend code
console.log('Available plugins:', Capacitor.Plugins);
console.log('BluetoothEcash plugin:', Capacitor.Plugins.BluetoothEcash);
```

### **Test 3: Check Build Output**

Verify the plugin is included in the build:

```bash
# Check if plugin files are in the built app
find /Users/dayi/Library/Developer/Xcode/DerivedData/App-*/Build/Products/Debug-iphonesimulator/App.app -name "*Bluetooth*"
```

## 📋 **Debugging Checklist**

- [ ] Verify plugin is in `capacitor.config.json`
- [ ] Check plugin class name matches Capacitor expectations
- [ ] Verify plugin methods are properly exposed
- [ ] Check Capacitor version compatibility
- [ ] Test plugin registration in AppDelegate
- [ ] Verify frontend can access plugin
- [ ] Check build output includes plugin files
- [ ] Test with minimal plugin implementation

## 🎯 **Expected Outcome**

After fixing the plugin registration issue:

1. **Plugin loads successfully** - `load()` method called
2. **Frontend can call plugin methods** - `BluetoothEcash.startService()` works
3. **Bluetooth service starts** - No more "failed to start bluetooth" errors
4. **Mesh networking works** - Peer discovery and token transfer functional

## 📚 **Reference Materials**

- [Capacitor Plugin Development Guide](https://capacitorjs.com/docs/plugins/creating-plugins)
- [Capacitor iOS Plugin Guide](https://capacitorjs.com/docs/ios/plugins)
- [BitChat Implementation Reference](/Users/dayi/git/bitchat/)

## 🔍 **Log Commands**

```bash
# Check for plugin loading logs
xcrun simctl spawn 04183335-F78E-4CCF-BB23-ECC40C662C39 log show --predicate 'process == "App" AND eventMessage contains "BluetoothEcashPlugin"' --last 2m

# Check for Capacitor logs
xcrun simctl spawn 04183335-F78E-4CCF-BB23-ECC40C662C39 log show --predicate 'process == "App" AND eventMessage contains "Capacitor"' --last 2m

# Check for plugin method calls
xcrun simctl spawn 04183335-F78E-4CCF-BB23-ECC40C662C39 log show --predicate 'process == "App" AND eventMessage contains "startService"' --last 2m
```

---

**This guide provides a systematic approach to debugging and fixing the Bluetooth plugin registration issue.**
