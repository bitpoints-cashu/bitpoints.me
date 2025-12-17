#!/bin/bash
# Generate icons for the app based on brand configuration
# Usage: ./scripts/generate-icons.sh [brand]
# Brand options: bitpoints (default) or trails

set -e

BRAND=${1:-bitpoints}

echo "🎨 Generating icons for brand: $BRAND"

if [ "$BRAND" = "bitpoints" ]; then
  ICON_SOURCE="icon.png"
  echo "Using main icon: $ICON_SOURCE"
elif [ "$BRAND" = "trails" ]; then
  ICON_SOURCE="src/assets/brands/trails/trails-iso.png"
  echo "Using trails icon: $ICON_SOURCE"
else
  echo "❌ Unknown brand: $BRAND"
  echo "Valid brands: bitpoints, trails"
  exit 1
fi

if [ ! -f "$ICON_SOURCE" ]; then
  echo "❌ Icon file not found: $ICON_SOURCE"
  exit 1
fi

echo "📱 Generating Android icons..."
npx @quasar/icongenie generate -i "$ICON_SOURCE" -m capacitor --skip-trim

echo "📱 Copying icons to main android directory..."
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  if [ -d "android/app/src/main/res/mipmap-$density" ]; then
    cp -f src-capacitor/android/app/src/main/res/mipmap-$density/ic_launcher*.png android/app/src/main/res/mipmap-$density/ 2>/dev/null || true
  fi
done

if [ "$BRAND" = "bitpoints" ]; then
  echo "🌐 Generating PWA icons..."
  npx @quasar/icongenie generate -i "$ICON_SOURCE" -m pwa --skip-trim
  echo "✅ PWA icons generated in public/icons/"
else
  echo "⚠️  Note: For trails brand, PWA icons should be generated manually from trails-iso.png"
  echo "   Required sizes: 128x128, 192x192, 256x256, 384x384, 512x512"
  echo "   Place in: public/icons/icon-*.png"
fi

echo "✅ Icon generation complete for brand: $BRAND"


