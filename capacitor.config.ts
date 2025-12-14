import type { CapacitorConfig } from "@capacitor/cli";

// Get active brand from environment
const getActiveBrandId = () => process.env.BRAND || "bitpoints";

// Brand configurations
const brandConfigs: Record<string, { appId: string; appName: string }> = {
  bitpoints: {
    appId: "me.bitpoints.wallet",
    appName: "Bitpoints.me",
  },
  trails: {
    appId: "com.trailscoffee.points",
    appName: "Trails Coffee Points",
  },
  pandewaffle: {
    appId: "me.bitpoints.pandewaffle",
    appName: "Pandewaffle",
  },
};

const activeBrandId = getActiveBrandId();
const brandConfig = brandConfigs[activeBrandId] || brandConfigs.bitpoints;

const config: CapacitorConfig = {
  appId: brandConfig.appId,
  appName: brandConfig.appName,
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
