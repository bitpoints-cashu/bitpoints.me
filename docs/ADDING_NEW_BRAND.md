# Adding a New Brand

This guide explains how to add a new brand to the multi-brand build system.

## Overview

The branding system supports multiple brands from a single codebase. Each brand has its own:
- Configuration (name, domain, colors)
- Assets (logos, icons, favicons)
- CSS styles
- Build output

## Step-by-Step Guide

### 1. Add Brand Configuration

Edit `src/config/brands.ts` and add your new brand to the `brands` object:

```typescript
yourbrand: {
  id: "yourbrand",
  name: "Your Brand Name",
  shortName: "Your Brand",
  domain: "yourbrand.com",
  logoPath: "yourbrand-logo.png",
  logoAlt: "Your Brand",
  colors: {
    primary: "#your-color",
    secondary: "#your-color",
    accent: "#your-color",
    background: "#your-color",
    text: "#your-color",
    theme: "#your-color", // PWA theme color
  },
  description: "Your brand description for manifests.",
  themeColor: "#your-theme-color",
  favicon: "yourbrand-favicon.ico",
  ogImage: "yourbrand-og-image.png",
  android: {
    packageName: "com.yourbrand.app",
    appName: "Your Brand App",
    iconPath: "yourbrand-icon.png",
  },
},
```

**Also update `quasar.config.js`** - Add the same brand config to the `getBrandConfig()` function's `brands` object (around line 40).

### 2. Create Brand Assets Directory

Create directory for brand assets:

```bash
mkdir -p src/assets/brands/yourbrand
```

### 3. Add Logo Assets

Add your brand logo to `src/assets/brands/yourbrand/`:
- `yourbrand-logo.png` - Main logo (used in header and welcome screen)
- Recommended sizes: 512x512px or larger, transparent background

### 4. Create Brand-Specific CSS

Create `src/css/brands/yourbrand.scss`:

```scss
/* Your Brand Branding - Custom Styles */

/* Import fonts (optional - customize as needed) */
@import url("https://fonts.googleapis.com/css2?family=YourFont:wght@400;600;700&display=swap");

/* Your Brand CSS Variables */
:root {
  --brand-primary: #your-color;
  --brand-secondary: #your-color;
  --brand-accent: #your-color;
  --brand-warm: #your-color;
  --brand-cream: #your-color;
  --brand-warm-white: #your-color;
  --brand-off-white: #your-color;
  --brand-charcoal: #your-color;
  --brand-soft-gray: #your-color;
  --brand-text-dark: #your-color;
  --brand-text-medium: #your-color;
  --brand-text-light: #your-color;
  --brand-shadow-soft: rgba(your-color, 0.1);
  --brand-shadow-medium: rgba(your-color, 0.15);
  --brand-gradient-warm: linear-gradient(135deg, #color1 0%, #color2 100%);
  --brand-gradient-subtle: linear-gradient(135deg, #color1 0%, #color2 100%);
  --brand-gradient-primary: linear-gradient(135deg, #color1 0%, #color2 100%);
  --brand-gradient-secondary: linear-gradient(135deg, #color1 0%, #color2 100%);
}

/* Copy structure from src/css/brands/bitpoints.scss */
/* Update colors and styling to match your brand */
```

See `src/css/brands/bitpoints.scss` and `src/css/brands/trails.scss` for reference.

### 5. Add Favicon and Icons (Optional)

Add brand-specific icons to `public/icons/` if needed, or reuse existing icons.

### 6. Update Build Scripts

Add your brand to `scripts/build-all-brands.js`:

```javascript
const brands = {
  // ... existing brands
  yourbrand: {
    id: 'yourbrand',
    name: 'Your Brand Name',
  },
};
```

Add to `scripts/package-deployments.js`:

```javascript
const brands = {
  // ... existing brands
  yourbrand: {
    id: 'yourbrand',
    name: 'Your Brand Name',
  },
};
```

### 7. Test Your Brand

#### Development Mode

Test your brand in dev mode:

```bash
npm run dev:yourbrand
```

Or set environment variable:

```bash
BRAND=yourbrand npm run dev
```

#### Production Build

Build all brands:

```bash
npm run build:pwa:all
```

This will create `dist/pwa/yourbrand/` with your branded build.

#### Verify Build Output

Check that:
- ✅ Correct logo appears in header and welcome screen
- ✅ Correct colors are applied
- ✅ Domain references are correct
- ✅ Manifest.json has correct branding
- ✅ No console errors

### 8. Create Deployment Package

Package all brands:

```bash
npm run package:all
```

This creates `yourbrand-v{version}-deployment.zip` in the project root.

## Files Modified/Created Summary

- ✅ `src/config/brands.ts` - Brand configuration
- ✅ `quasar.config.js` - Brand config in getBrandConfig()
- ✅ `src/assets/brands/yourbrand/` - Brand assets directory
- ✅ `src/css/brands/yourbrand.scss` - Brand styles
- ✅ `scripts/build-all-brands.js` - Build script
- ✅ `scripts/package-deployments.js` - Package script

## Required Assets

### Logo
- **Format**: PNG with transparent background
- **Size**: 512x512px minimum (larger is fine)
- **File**: `src/assets/brands/yourbrand/yourbrand-logo.png`

### Optional Assets
- Favicon: `public/icons/yourbrand-favicon.ico`
- OpenGraph image: `public/yourbrand-og-image.png`
- Android icons: Various sizes in `resources/android/`

## Color Guidelines

Define a complete color palette in your brand config:

- `primary`: Main brand color (buttons, links)
- `secondary`: Secondary brand color
- `accent`: Accent color for highlights
- `background`: Main background color
- `text`: Primary text color
- `theme`: PWA theme color (shown in browser UI)

Ensure sufficient contrast between text and background colors for accessibility.

## Testing Checklist

- [ ] Dev mode loads with correct brand
- [ ] Logo appears correctly in MainHeader
- [ ] Logo appears correctly in WelcomeSlide1
- [ ] Colors match brand guidelines
- [ ] Domain references use brand domain
- [ ] Manifest.json has correct name/description
- [ ] PWA theme color matches brand
- [ ] Build completes successfully
- [ ] Deployment package created
- [ ] No console errors or warnings

## Troubleshooting

### Logo Not Appearing

- Check file path: `src/assets/brands/{brand-id}/{logo-filename}`
- Verify logo path in brand config matches filename
- Check browser console for 404 errors

### Wrong Colors

- Verify CSS file is loaded: check `quasar.config.js` CSS array includes `brands/{brand-id}.scss`
- Check CSS variables are defined correctly
- Clear browser cache and rebuild

### Build Fails

- Verify brand config exists in both `brands.ts` and `quasar.config.js`
- Check that CSS file exists: `src/css/brands/{brand-id}.scss`
- Look for syntax errors in brand config

### Domain Not Working

- Verify domain is set correctly in brand config
- Check that stores using `getBrandDomain()` import the utility correctly
- Rebuild after changing domain

## Next Steps

After adding your brand:

1. Test thoroughly in dev and production modes
2. Build all brands: `npm run build:pwa:all`
3. Package for deployment: `npm run package:all`
4. Deploy the zip file to your domain

## Future Enhancements

For Android builds (future):
- Add brand to Android build scripts
- Configure package name and app name
- Add brand-specific icons to Android resources

