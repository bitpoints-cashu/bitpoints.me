/**
 * Branding Utility Functions
 *
 * Provides runtime access to branding configuration and asset resolution.
 * Works in both dev and production builds.
 */

import {
  getBrandConfig,
  getActiveBrandId,
  type BrandConfig,
} from "../config/brands";

/**
 * Get the active brand configuration
 * If brandId is provided, returns that specific brand config
 */
export function getBrand(brandId?: string): BrandConfig {
  return getBrandConfig(brandId);
}

/**
 * Get brand-specific asset path
 * Resolves relative paths to the correct brand asset directory
 *
 * @param relativePath - Path relative to assets/brands/{brandId}/
 * @param brandId - Optional brand ID, uses active brand if not provided
 * @returns Resolved asset path
 *
 * @example
 * getBrandAsset('logo.png') -> '~assets/brands/bitpoints/logo.png'
 * getBrandAsset('logo.png', 'trails') -> '~assets/brands/trails/logo.png'
 */
export function getBrandAsset(relativePath: string, brandId?: string): string {
  const brand = getBrand(brandId);
  return `~assets/brands/${brand.id}/${relativePath}`;
}

/**
 * Get brand-specific color value
 *
 * @param colorKey - Color key from brand config (primary, secondary, accent, etc.)
 * @param brandId - Optional brand ID, uses active brand if not provided
 * @returns Color hex value
 */
export function getBrandColor(
  colorKey: keyof BrandConfig["colors"],
  brandId?: string
): string {
  const brand = getBrand(brandId);
  return brand.colors[colorKey] || brand.colors.primary;
}

/**
 * Get active brand ID
 */
export function getActiveBrand(): string {
  return getActiveBrandId();
}

/**
 * Get active brand ID (re-exported from brands config for convenience)
 */
export { getActiveBrandId } from "../config/brands";

/**
 * Get brand name
 */
export function getBrandName(brandId?: string): string {
  return getBrand(brandId).name;
}

/**
 * Get brand short name
 */
export function getBrandShortName(brandId?: string): string {
  return getBrand(brandId).shortName;
}

/**
 * Get brand domain
 */
export function getBrandDomain(brandId?: string): string {
  return getBrand(brandId).domain;
}

/**
 * Get brand logo path
 */
export function getBrandLogo(brandId?: string): string {
  const brand = getBrand(brandId);
  return getBrandAsset(brand.logoPath, brandId);
}
