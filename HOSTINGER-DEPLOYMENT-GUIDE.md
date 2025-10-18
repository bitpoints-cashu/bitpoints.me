# 🚀 Trails Coffee Rewards - Hostinger Deployment Guide

## 📦 Files Ready for Deployment

Two files are ready in `/home/juli/git/cashu.me/`:

1. **`trails-coffee-rewards-deployment.zip`** (4.6 MB) - Production build
2. **`trails-coffee-rewards-v1.0.zip`** (6.3 MB) - Source code backup

## 🎯 Deployment Steps for Hostinger

### Method 1: Using Hostinger File Manager (Recommended)

#### Step 1: Access Hostinger Control Panel

1. Log in to your Hostinger account at https://hpanel.hostinger.com
2. Select your hosting plan
3. Go to **Files** → **File Manager**

#### Step 2: Prepare the Directory

1. Navigate to `public_html` (or your domain's root directory)
2. **Important**: If you want to deploy to the root domain:
   - Delete or backup the existing `index.html` (if any)
   - Clear the directory or create a new subdirectory

#### Step 3: Upload the Deployment Package

1. Click **Upload Files** in the File Manager
2. Upload `trails-coffee-rewards-deployment.zip`
3. Right-click the ZIP file and select **Extract**
4. The files will be extracted to the current directory
5. Delete the ZIP file after extraction

#### Step 4: Verify File Structure

Your directory should contain:

```
public_html/
├── index.html
├── manifest.json
├── sw.js
├── .htaccess
├── assets/
├── icons/
└── screenshots/
```

#### Step 5: Configure Domain (if needed)

- **Option A: Main Domain**
  - Files in `public_html/` → Access at `https://yourdomain.com`
- **Option B: Subdomain**

  - Create subdomain: `rewards.yourdomain.com`
  - Upload files to the subdomain directory
  - Access at `https://rewards.yourdomain.com`

- **Option C: Subdirectory**
  - Create folder: `public_html/rewards/`
  - Upload files there
  - Access at `https://yourdomain.com/rewards/`
  - **Note**: Update `base` tag in `index.html` to `/rewards/`

### Method 2: Using FTP/SFTP

#### Requirements:

- FTP client (FileZilla, WinSCP, Cyberduck)
- Hostinger FTP credentials

#### Steps:

1. **Get FTP Credentials**:

   - Hostinger Control Panel → **Files** → **FTP Accounts**
   - Note: Hostname, Username, Password, Port

2. **Connect via FTP**:

   - Open your FTP client
   - Connect using the credentials
   - Navigate to `public_html/`

3. **Upload Files**:

   - Extract `trails-coffee-rewards-deployment.zip` on your local machine
   - Upload all extracted files to `public_html/`
   - Ensure `.htaccess` is uploaded (may be hidden)

4. **Set Permissions**:
   - All files: 644
   - All directories: 755

### Method 3: Using SSH (VPS/Business Plans)

```bash
# Connect to your server
ssh your-username@your-server-ip

# Navigate to web root
cd ~/public_html

# Upload the deployment package (use scp or wget)
# Then extract:
unzip trails-coffee-rewards-deployment.zip

# Set proper permissions
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;
```

## ⚙️ Post-Deployment Configuration

### 1. SSL Certificate (HTTPS)

Hostinger provides free SSL certificates:

1. Go to **SSL** in hPanel
2. Install **Free SSL Certificate**
3. Wait 5-15 minutes for activation
4. Your app MUST be accessed via HTTPS for PWA features to work

### 2. Test PWA Features

- **Desktop**: Chrome → Menu → Install Trails Coffee Rewards
- **Mobile**: Add to Home Screen option should appear
- **Service Worker**: Check in DevTools → Application → Service Workers

### 3. Custom Domain Setup (Optional)

If using a custom domain:

1. Point DNS to Hostinger nameservers
2. Wait for propagation (24-48 hours)
3. Install SSL certificate
4. Test the deployment

## 🔍 Verification Checklist

After deployment, verify:

- [ ] ✅ Site loads at your domain
- [ ] ✅ HTTPS is working (green padlock)
- [ ] ✅ All images and assets load correctly
- [ ] ✅ Can install as PWA
- [ ] ✅ Service worker is active
- [ ] ✅ Can receive ecash tokens
- [ ] ✅ Can send ecash tokens
- [ ] ✅ Trails Coffee mint is connected
- [ ] ✅ Balance shows correctly

## 🐛 Troubleshooting

### Issue: White/Blank Page

**Solution**: Check browser console for errors

- Verify all files uploaded correctly
- Check `.htaccess` is present
- Ensure mod_rewrite is enabled on server

### Issue: 404 Errors on Navigation

**Solution**:

- Verify `.htaccess` file is present and uploaded
- Contact Hostinger support to enable mod_rewrite

### Issue: PWA Not Installing

**Solution**:

- Ensure site is accessed via HTTPS
- Check manifest.json is accessible
- Clear browser cache and try again

### Issue: Service Worker Not Registering

**Solution**:

- Check sw.js is accessible at root
- Verify HTTPS is working
- Check console for errors

### Issue: Assets Not Loading

**Solution**:

- Check file permissions (644 for files, 755 for directories)
- Verify all assets were uploaded
- Check browser console for 404 errors

## 📱 Mobile Testing

### iOS (iPhone/iPad):

1. Open Safari and visit your site
2. Tap Share button
3. Select "Add to Home Screen"
4. Name it "Trails Coffee Rewards"
5. Tap "Add"

### Android:

1. Open Chrome and visit your site
2. Tap menu (⋮)
3. Select "Add to Home Screen"
4. Follow prompts

## 🔧 Advanced Configuration

### Custom Domain Settings

If you want to use a subdomain like `rewards.trailscoffee.com`:

1. **Create Subdomain in Hostinger**:

   - Go to **Domains** → **Subdomains**
   - Create: `rewards`
   - Set document root to a new directory

2. **Upload Files**:

   - Upload all files to the subdomain directory
   - Install SSL for the subdomain

3. **DNS Propagation**:
   - Wait 15 minutes to 24 hours for DNS to propagate

### Environment Variables (if needed)

The app is pre-configured with:

- Default Mint: `https://ecash.trailscoffee.com`
- Default Unit: `points`
- App Name: `Trails Coffee Rewards`

No environment variables needed!

## 📞 Support

### Hostinger Support

- Live Chat: 24/7 in hPanel
- Email: support@hostinger.com
- Knowledge Base: https://support.hostinger.com

### App Issues

Check the browser console for errors and verify:

- Mint URL is accessible
- HTTPS is enabled
- Service worker is registered

## 🎉 Success!

Once deployed, your customers can:

- 📱 Install the app on their phones
- 💰 Receive rewards as ecash tokens
- 🎁 Use gift cards
- 📤 Send and receive points
- 🔒 Keep their funds secure

**Your Trails Coffee Rewards app is now live!** ☕🎉

---

## 📦 File Locations

**Deployment Package**: `/home/juli/git/cashu.me/trails-coffee-rewards-deployment.zip`
**Source Backup**: `/home/juli/git/cashu.me/trails-coffee-rewards-v1.0.zip`
**Build Directory**: `/home/juli/git/cashu.me/dist/pwa/`

## 🔄 Updating the App

To update the app in the future:

1. Make changes to source code
2. Run: `npm run build:pwa`
3. Create new ZIP: `cd dist/pwa && zip -r ../../deployment-new.zip .`
4. Upload and extract new ZIP to Hostinger
5. Clear browser cache and test

---

**Deployment Date**: October 7, 2025
**Version**: 1.0 (backup-v1.0)
**Build**: Production PWA

