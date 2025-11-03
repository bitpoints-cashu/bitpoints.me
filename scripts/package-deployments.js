#!/usr/bin/env node

/**
 * Package Deployments Script
 *
 * Creates zip packages for all built brand PWAs.
 * Outputs: {brandId}-v{version}-deployment.zip
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Brand configurations
const brands = {
  bitpoints: {
    id: "bitpoints",
    name: "Bitpoints.me",
  },
  trails: {
    id: "trails",
    name: "Trails Coffee Points",
  },
};

// Get version from package.json
function getVersion() {
  const packageJsonPath = path.resolve(__dirname, "../package.json");
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  return packageJson.version;
}

function createZip(brandId, outputPath) {
  const brand = brands[brandId];
  if (!brand) {
    console.error(`❌ Unknown brand: ${brandId}`);
    return false;
  }

  const buildDir = path.resolve(__dirname, `../dist/pwa/${brandId}`);

  if (!fs.existsSync(buildDir)) {
    console.error(`❌ Build directory not found: ${buildDir}`);
    console.error(`   Run "npm run build:pwa:all" first.`);
    return false;
  }

  console.log(`📦 Packaging ${brand.name}...`);

  try {
    // Create zip file
    // Using zip command (available on most systems)
    const zipCommand = `cd "${buildDir}" && zip -r "${outputPath}" . -x "*.map" ".DS_Store" "*.log"`;
    execSync(zipCommand, { stdio: "inherit" });

    // Verify zip was created
    if (fs.existsSync(outputPath)) {
      const stats = fs.statSync(outputPath);
      const sizeMB = (stats.size / (1024 * 1024)).toFixed(2);
      console.log(`✅ Created: ${path.basename(outputPath)} (${sizeMB} MB)`);
      return true;
    } else {
      console.error(`❌ Zip file not created: ${outputPath}`);
      return false;
    }
  } catch (error) {
    console.error(`❌ Failed to create zip for ${brand.name}:`, error.message);
    return false;
  }
}

function main() {
  console.log("📦 Packaging all brand deployments...\n");

  const version = getVersion();
  const outputDir = path.resolve(__dirname, "..");
  const results = {};

  // Create zip for each brand
  for (const brandId of Object.keys(brands)) {
    const outputPath = path.resolve(
      outputDir,
      `${brandId}-v${version}-deployment.zip`
    );
    results[brandId] = createZip(brandId, outputPath);
    console.log("");
  }

  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("📋 Package Summary:\n");

  let allSuccess = true;
  for (const [brandId, success] of Object.entries(results)) {
    const status = success ? "✅" : "❌";
    const outputPath = path.resolve(
      outputDir,
      `${brandId}-v${version}-deployment.zip`
    );
    const filename = path.basename(outputPath);
    console.log(`  ${status} ${brands[brandId].name}`);
    if (success) {
      console.log(`     → ${filename}`);
    }
    if (!success) allSuccess = false;
  }

  if (allSuccess) {
    console.log("\n✨ All packages created successfully!");
    console.log(`\n📁 Packages location: ${outputDir}\n`);
    process.exit(0);
  } else {
    console.log("\n⚠️  Some packages failed. Check the output above.");
    process.exit(1);
  }
}

main();
