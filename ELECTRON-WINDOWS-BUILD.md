# 🖥️ Bitpoints.me - Windows Desktop App (Electron)

## 🎯 Why Electron for Bluetooth Testing?

The Electron desktop app solves the SSL certificate issue that blocks Web Bluetooth in browsers:

✅ **No SSL Required**: Native app doesn't need HTTPS  
✅ **Full Bluetooth Access**: Direct system Bluetooth permissions  
✅ **No Browser Restrictions**: Complete Web Bluetooth API access  
✅ **Easy Testing**: Run locally without deployment  

---

## 🧪 Testing in Development Mode

### **1. Run Electron Dev Mode**

The Electron app should be starting now with the command:
```bash
quasar dev -m electron
```

### **2. What Will Happen**

- A desktop window will open with the Bitpoints.me app
- The app runs as a native Windows application
- DevTools will be open automatically (for debugging)
- All console logs will appear in the terminal AND DevTools

### **3. Test Web Bluetooth**

Once the Electron window opens:

1. **Go to Settings** → **Bluetooth Mesh**
2. **Click "Connect Device"**
3. **Watch the console** for detailed logs:
   ```
   🔍 Bluetooth devices found: 2
     1. Samsung Galaxy (12:34:56:78:9A:BC)
     2. iPhone (AB:CD:EF:12:34:56)
   ✅ Selected device: Samsung Galaxy
   ```

4. **Device should connect automatically!**

### **4. Or Test Diagnostics Page**

Navigate to: **Settings** → Type in URL bar: `#/bluetooth-diagnostics`

This will show:
- ✅ Electron platform detected
- ✅ Web Bluetooth API available
- ✅ Test device picker button

---

## 📦 Building Windows Executable (.exe)

### **Option 1: Quick Build (Portable)**

Build a portable exe that doesn't require installation:

```bash
cd C:\Users\JuanPabloGaviria\git\cashu.me
npm run build:electron
```

**Output Location**: `dist\electron\Packaged\`

**What You Get**:
- `Bitpoints-win-x64\` folder
- Contains `Bitpoints.exe`
- Portable - can run from anywhere
- No installation needed

### **Option 2: Installer Build**

To create a proper Windows installer (.exe):

1. **Install electron-builder** (if not already):
```bash
npm install --save-dev electron-builder
```

2. **Build with installer**:
```bash
npm run build:electron
```

3. **Find the installer**:
   - Look in `dist\electron\Packaged\`
   - File: `Bitpoints Setup x.x.x.exe`

---

## 🔍 Troubleshooting

### **Issue: Electron window doesn't open**

**Check terminal output for errors**

Common issues:
- Node modules not installed: `npm install`
- Electron not installed: Quasar should auto-install it

### **Issue: "Connect Device" still doesn't work**

**Check these in DevTools console**:

1. Is `navigator.bluetooth` available?
   ```javascript
   console.log('Bluetooth API:', navigator.bluetooth)
   ```

2. Are you on the Electron platform?
   ```javascript
   console.log('Platform:', process.versions.electron)
   ```

3. Try the diagnostics page:
   - Type in URL bar: `#/bluetooth-diagnostics`
   - Click "Test Device Picker"
   - Watch console for errors

### **Issue: No devices found**

1. **Enable Bluetooth on Windows**:
   - Settings → Bluetooth & devices
   - Turn on Bluetooth

2. **Enable Bluetooth on Android phone**:
   - Settings → Connections → Bluetooth

3. **Make phone discoverable**:
   - Make sure Bitpoints app is running on phone
   - Bluetooth mesh is enabled

4. **Check Windows Bluetooth drivers**:
   - Device Manager → Bluetooth
   - Ensure drivers are installed

---

## 🎯 Expected Behavior

### **Development Mode** (`quasar dev -m electron`):
- ✅ Window opens with app
- ✅ DevTools open automatically
- ✅ Hot reload works (changes auto-update)
- ✅ Console logs visible
- ✅ Bluetooth device picker works

### **Production Build** (`npm run build:electron`):
- ✅ Creates standalone `.exe`
- ✅ No DevTools (unless enabled)
- ✅ Optimized bundle size
- ✅ Can be distributed
- ✅ Runs without Node.js

---

## 📊 Console Logs to Watch For

### **When clicking "Connect Device"**:

```
🖥️ Desktop PWA detected, using Web Bluetooth...
✅ Web Bluetooth available, starting service...
🔗 Current URL: file://...
🎯 Requesting Bluetooth device...
🔍 Starting Web Bluetooth device discovery...
```

### **Electron Bluetooth handler**:

```
🔍 Bluetooth devices found: 2
  1. Samsung Galaxy S21 (12:34:56:78:9A:BC)
  2. Bitpoints User ABC (AB:CD:EF:12:34:56)
✅ Selected device: Bitpoints User ABC
```

### **Connection success**:

```
✅ Found generic BLE device: Bitpoints User ABC
🎉 Device connected successfully: { id: ..., nickname: ... }
✅ Web Bluetooth service started
```

---

## 🚀 Distribution

### **Sharing the App**:

1. **Build the installer**:
   ```bash
   npm run build:electron
   ```

2. **Find the exe**:
   - `dist\electron\Packaged\Bitpoints Setup x.x.x.exe`

3. **Share**:
   - Upload to GitHub Releases
   - Share via Google Drive / Dropbox
   - Users double-click to install

### **File Size**:
- **Development**: ~150-200 MB (uncompressed)
- **Production**: ~80-120 MB (installer)
- **Installed**: ~200-250 MB

---

## 🔧 Advanced Configuration

### **Icon Customization**:

Replace icons in `src-electron/icons/`:
- `icon.ico` (Windows)
- `icon.png` (Linux)
- `icon.icns` (macOS)

### **Window Size**:

Edit `src-electron/electron-main.ts`:
```typescript
width: 1200,  // Change width
height: 800,  // Change height
```

### **DevTools in Production**:

To enable DevTools in production build:
```typescript
if (process.env.DEBUGGING) {
  mainWindow.webContents.openDevTools();
}
```

Set environment variable before running:
```bash
set DEBUGGING=true
Bitpoints.exe
```

---

## 📱 Testing with Android App

### **1. Enable Bluetooth on Both Devices**:
- Windows computer: Bluetooth ON
- Android phone: Bluetooth ON + Bitpoints app running

### **2. Set Custom Nicknames**:
- Desktop: Settings → Bluetooth → "Windows Desktop"
- Android: Settings → Bluetooth → "My Phone"

### **3. Test Connection**:
- Desktop: Click "Connect Device"
- Watch console for device list
- Should auto-connect to first device found

### **4. Test Token Transfer**:
- Desktop: Send token to nearby peer
- Android: Should receive token
- Check balance on both devices

---

## 🎉 Success Checklist

- [ ] Electron window opens
- [ ] DevTools show console logs
- [ ] Bluetooth API available (`navigator.bluetooth`)
- [ ] "Connect Device" shows device picker
- [ ] Nearby devices appear in list
- [ ] Device connects successfully
- [ ] Token transfer works
- [ ] Built .exe runs independently

---

**The Electron app is starting now! Watch for the desktop window to open.** 🖥️

Once it opens, test the Bluetooth connection and let me know what happens!


