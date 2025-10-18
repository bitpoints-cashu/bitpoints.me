# Trails Coffee Rewards - Deployment Guide v1.2

## What's New in v1.2

- ✅ **Larger Trails Coffee Logo**: Increased from 40px to 100px height for better visibility
- ✅ **Cleaner Main Page**: Hidden mint information below balance for cleaner UI
- ✅ **Simplified Menu**: Removed external links, only Settings and Terms remain
- ✅ **Footer Credits**: Added proper attribution to cashu.me with support links
- ✅ **Updated Terms**: All "Cashu.me" references changed to "Trails Coffee Rewards"
- ✅ **Better Layout**: Fixed footer positioning at bottom of page

## Files Included

- `trails-coffee-rewards-v1.2-final.zip` - Complete PWA build ready for deployment

## Deployment Instructions for Hostinger

### 1. Upload Files

1. Extract `trails-coffee-rewards-v1.2-final.zip`
2. Upload all contents to your Hostinger public_html directory
3. Ensure `index.html` is in the root of public_html

### 2. Configure .htaccess (if not already present)

Create or update `.htaccess` in your public_html directory:

```apache
RewriteEngine On
RewriteBase /

# Handle Angular and Vue Router
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]

# Cache static assets
<FilesMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$">
    ExpiresActive On
    ExpiresDefault "access plus 1 year"
</FilesMatch>

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
```

### 3. Verify Deployment

- Visit your domain
- Check that the Trails Coffee logo is large and visible
- Test the send/receive functionality
- Verify the footer shows proper credits
- Check that the menu only shows Settings and Terms

## Features

- **Default Mint**: ecash.trailscoffee.com
- **Currency**: Points (maps to sats internally)
- **PWA**: Installable on mobile devices
- **Responsive**: Works on all screen sizes
- **Offline**: Works without internet connection

## Support Links in Footer

- [cashu.me GitHub](https://github.com/cashubtc/cashu.me) - Original open-source wallet
- [cashu.space](https://cashu.space) - Cashu ecosystem
- [OpenCash.dev](https://opencash.dev/) - Support digital cash development

## Version History

- v1.0: Initial branded version
- v1.1: UI updates and menu cleanup
- v1.2: Larger logo, cleaner UI, footer credits (current)

---

_Built with ❤️ using the open-source cashu.me wallet_
