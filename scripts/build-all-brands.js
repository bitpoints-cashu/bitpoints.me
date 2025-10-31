#!/usr/bin/env node

/**
 * Build All Brands Script
 * 
 * Builds PWA for all configured brands sequentially.
 * Each brand is built to its own output directory: dist/pwa/{brandId}/
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Brand configurations (matches quasar.config.js)
const brands = {
  bitpoints: {
    id: 'bitpoints',
    name: 'Bitpoints.me',
  },
  trails: {
    id: 'trails',
    name: 'Trails Coffee Points',
  },
};

function buildBrand(brandId) {
  const brand = brands[brandId];
  if (!brand) {
    console.error(`❌ Unknown brand: ${brandId}`);
    return false;
  }

  console.log(`\n🏷️  Building ${brand.name} (${brandId})...`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);

  try {
    // Set BRAND environment variable and run build
    const env = { ...process.env, BRAND: brandId };
    
    execSync('npm run build:pwa', {
      env,
      stdio: 'inherit',
      cwd: path.resolve(__dirname, '..'),
    });

    // Verify output directory was created
    const outputDir = path.resolve(__dirname, `../dist/pwa/${brandId}`);
    if (fs.existsSync(outputDir)) {
      console.log(`✅ ${brand.name} build complete: ${outputDir}`);
      return true;
    } else {
      console.error(`❌ Build output not found: ${outputDir}`);
      return false;
    }
  } catch (error) {
    console.error(`❌ Failed to build ${brand.name}:`, error.message);
    return false;
  }
}

function main() {
  console.log('🚀 Building all brands...\n');
  
  const brandIds = Object.keys(brands);
  const results = {};
  
  for (const brandId of brandIds) {
    results[brandId] = buildBrand(brandId);
  }
  
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📦 Build Summary:\n');
  
  let allSuccess = true;
  for (const [brandId, success] of Object.entries(results)) {
    const status = success ? '✅' : '❌';
    console.log(`  ${status} ${brands[brandId].name}`);
    if (!success) allSuccess = false;
  }
  
  if (allSuccess) {
    console.log('\n✨ All brands built successfully!');
    process.exit(0);
  } else {
    console.log('\n⚠️  Some builds failed. Check the output above.');
    process.exit(1);
  }
}

main();

