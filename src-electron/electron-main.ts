import { app, BrowserWindow } from "electron";
import path from "path";
import os from "os";

// needed in case process is undefined under Linux
const platform = process.platform || os.platform();

let mainWindow: BrowserWindow | undefined;

function createWindow() {
  /**
   * Initial window options
   */
  mainWindow = new BrowserWindow({
    icon: path.resolve(__dirname, "icons/icon.png"), // tray icon
    width: 1000,
    height: 600,
    useContentSize: true,
    webPreferences: {
      contextIsolation: true,
      // More info: https://v2.quasar.dev/quasar-cli-vite/developing-electron-apps/electron-preload-script
      preload: path.resolve(__dirname, process.env.QUASAR_ELECTRON_PRELOAD),
      // Enable Web Bluetooth API
      enableBlinkFeatures: 'WebBluetooth',
    },
  });

  // Handle Bluetooth device selection
  mainWindow.webContents.session.on('select-bluetooth-device', (event, deviceList, callback) => {
    event.preventDefault();
    console.log('🔍 Bluetooth devices found:', deviceList.length);
    
    if (deviceList && deviceList.length > 0) {
      // Log available devices
      deviceList.forEach((device, index) => {
        console.log(`  ${index + 1}. ${device.deviceName || 'Unknown'} (${device.deviceId})`);
      });
      
      // Select the first device automatically for now
      // In a real app, you'd show a dialog to let the user choose
      callback(deviceList[0].deviceId);
      console.log(`✅ Selected device: ${deviceList[0].deviceName || 'Unknown'}`);
    } else {
      console.log('❌ No Bluetooth devices found');
      callback('');
    }
  });

  // Handle Bluetooth pairing
  mainWindow.webContents.session.setBluetoothPairingHandler((details, callback) => {
    console.log('🔐 Bluetooth pairing request:', details);
    // Auto-confirm pairing for testing
    // In production, show a dialog
    callback({ confirmed: true });
  });

  mainWindow.loadURL(process.env.APP_URL);

  if (process.env.DEBUGGING) {
    // if on DEV or Production with debug enabled
    mainWindow.webContents.openDevTools();
  } else {
    // we're on production; no access to devtools pls
    mainWindow.webContents.on("devtools-opened", () => {
      mainWindow?.webContents.closeDevTools();
    });
  }

  mainWindow.on("closed", () => {
    mainWindow = undefined;
  });
}

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  if (mainWindow === undefined) {
    createWindow();
  }
});
