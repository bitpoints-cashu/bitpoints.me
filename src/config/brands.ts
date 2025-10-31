/**
 * Brand Configuration
 *
 * Centralized configuration for all supported brands.
 * Each brand defines its name, domain, colors, assets, and other brand-specific settings.
 */

// Declare build-time injected constants from Vite define
// Vite replaces __BRAND_ID__ with the actual value at build time
declare const __BRAND_ID__: string | undefined;
declare const __BRAND_CONFIG__: any | undefined;

export interface BrandColors {
  primary: string;
  secondary: string;
  accent: string;
  background: string;
  text: string;
  theme: string; // PWA theme color
  warm?: string;
  cream?: string;
  charcoal?: string;
}

export interface BrandConfig {
  id: string;
  name: string;
  shortName: string;
  domain: string;
  logoPath: string;
  logoAlt: string;
  colors: BrandColors;
  description: string;
  themeColor: string;
  favicon: string;
  ogImage: string;
  android?: {
    packageName: string;
    appName: string;
    iconPath: string;
  };
}

const brands: Record<string, BrandConfig> = {
  bitpoints: {
    id: "bitpoints",
    name: "Bitpoints.me",
    shortName: "Bitpoints",
    domain: "bitpoints.me",
    logoPath: "bitpoints-logo.png",
    logoAlt: "Bitpoints",
    colors: {
      primary: "#ff6b35",
      secondary: "#6b4fbb",
      accent: "#ff8c42",
      background: "#fffef7",
      text: "#1a1a1a",
      theme: "#6B4FBB",
      warm: "#ffb366",
      cream: "#fff8f0",
      charcoal: "#2c2c2c",
    },
    description:
      "Bitcoin-backed rewards that appreciate over time. Powered by Cashu ecash, Nostr identity, and Bluetooth mesh.",
    themeColor: "#6B4FBB",
    favicon: "favicon.ico",
    ogImage: "og-image.png",
    android: {
      packageName: "me.bitpoints.wallet",
      appName: "Bitpoints.me",
      iconPath: "icon.png",
    },
  },
  trails: {
    id: "trails",
    name: "Trails Coffee Points",
    shortName: "Trails Points",
    domain: "points.trailscoffee.com",
    logoPath: "trails-logo.png",
    logoAlt: "Trails Coffee",
    colors: {
      // Trails Coffee brand colors - adjust based on actual brand guidelines
      // Using warm coffee/brown tones as placeholder
      primary: "#8B4513", // Saddle brown (coffee color)
      secondary: "#D2691E", // Chocolate
      accent: "#CD853F", // Peru (warm accent)
      background: "#FFF8DC", // Cornsilk (light warm background)
      text: "#3E2723", // Dark brown text
      theme: "#6F4E37", // Coffee brown for PWA theme
      warm: "#A0522D", // Sienna
      cream: "#FFF8E7", // Light cream
      charcoal: "#2F1B14", // Dark coffee
    },
    description:
      "Rewards points powered by Bitcoin. Earn, send, and receive points with Trails Coffee.",
    themeColor: "#6F4E37",
    favicon: "trails-favicon.ico",
    ogImage: "trails-og-image.png",
    android: {
      packageName: "com.trailscoffee.points",
      appName: "Trails Coffee Points",
      iconPath: "trails-icon.png",
    },
  },
};

/**
 * Get brand configuration by ID
 */
export function getBrandConfig(brandId?: string): BrandConfig {
  const activeBrandId = brandId || getActiveBrandId();
  const brand = brands[activeBrandId];

  if (!brand) {
    console.warn(`Brand "${activeBrandId}" not found, defaulting to bitpoints`);
    return brands.bitpoints;
  }

  return brand;
}

/**
 * Get active brand ID from environment or default to bitpoints
 */
export function getActiveBrandId(): string {
  // First, check for build-time injected BRAND_ID from Vite define
  // Vite's define replaces __BRAND_ID__ with the actual string value at build time
  // @ts-ignore - Vite injects this at build time
  if (typeof __BRAND_ID__ !== "undefined") {
    // @ts-ignore
    const injected = __BRAND_ID__;
    // Remove quotes if Vite injected as JSON string
    if (typeof injected === "string") {
      return injected.replace(/^"|"$/g, "");
    }
    return String(injected);
  }

  // Check for BRAND environment variable (set at build time or runtime)
  if (typeof process !== "undefined" && process.env?.BRAND) {
    return process.env.BRAND;
  }

  // Check for window location (dev mode or runtime)
  if (typeof window !== "undefined") {
    const hostname = window.location.hostname;
    // For localhost testing, check URL params
    if (hostname.includes("localhost")) {
      const urlParams = new URLSearchParams(window.location.search);
      const brandParam = urlParams.get("brand");
      if (brandParam === "trails" || brandParam === "bitpoints") {
        return brandParam;
      }
      // Check localStorage for brand preference (useful for testing)
      try {
        const storedBrand = localStorage.getItem("activeBrand");
        if (storedBrand === "trails" || storedBrand === "bitpoints") {
          return storedBrand;
        }
      } catch (e) {
        // localStorage not available
      }
    }
    if (hostname.includes("trailscoffee.com")) {
      return "trails";
    }
    if (hostname.includes("bitpoints.me")) {
      return "bitpoints";
    }
  }

  // Default to bitpoints
  return "bitpoints";
}

/**
 * Get list of all brand IDs
 */
export function getAllBrandIds(): string[] {
  return Object.keys(brands);
}

/**
 * Get all brand configurations
 */
export function getAllBrands(): Record<string, BrandConfig> {
  return brands;
}

export default brands;
