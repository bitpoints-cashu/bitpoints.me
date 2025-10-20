import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "me.bitpoints.wallet",
  appName: "Bitpoints.me",
  webDir: "dist/spa/",
};

// Wear OS configuration
const wearConfig: CapacitorConfig = {
  appId: "me.bitpoints.wear",
  appName: "Bitpoints Wear",
  webDir: "dist/wear/",
  android: {
    path: "android/wear",
  },
};

// Export based on environment or build target
export default process.env.CAPACITOR_TARGET === "wear" ? wearConfig : config;
