import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "me.bitpoints.wallet",
  appName: "Bitpoints.me",
  webDir: "dist/spa/",
  android: {
    includePlugins: ["BluetoothEcash"],
  },
  ios: {
    includePlugins: ["BluetoothEcash"],
  },
};

export default config;
