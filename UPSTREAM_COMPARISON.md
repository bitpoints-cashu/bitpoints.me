# Upstream Comparison: Bitpoints.me vs Cashu.me

**Comparison Date**: 2025-01-27  
**Your Current Branch**: `restore-working-bluetooth`  
**Upstream Branch**: `cashubtc/cashu.me:main`  
**Commits Behind**: ~1,205 commits

## Summary of Changes

### Additions (New Files) - 200+ files
- **Android Bluetooth Mesh**: 80+ Kotlin files for bitchat protocol integration
- **Documentation**: 15+ markdown files for Bluetooth development
- **iOS Integration**: iOS-specific files and documentation
- **Wear OS**: Wear OS implementation files
- **Additional Features**: `watchIntegration.ts`, network security config

### Modifications - 98 files changed

## Key Differences by Category

### 1. Branding Changes
**Status**: Custom Bitpoints branding throughout

**Files Modified**:
- `src/stores/ui.ts` - "Satoshis" → "Points", "sat" → "points"
- `src/stores/npubcash.ts` - Domain: "npub.cash" → "bitpoints.me"
- `package.json` - Product name: "Bitpoints"
- `android/app/src/main/AndroidManifest.xml` - Package: `me.bitpoints.wallet`

**Decision Required**: 
- [ ] Keep Bitpoints branding (sat/points terminology)
- [ ] Switch back to Cashu branding

### 2. Default Mint Configuration
**Status**: Pre-configured with Trails Coffee mint

**Files Modified**:
- `src/stores/mints.ts` - Default mint URL and initialization
- `src/pages/WalletPage.vue` - Auto-activation of Trails Coffee mint

**Your Changes**:
```typescript
// Default mint URL
"cashu.activeMintUrl", "https://ecash.trailscoffee.com"

// Pre-configured mint
{
  url: "https://ecash.trailscoffee.com",
  nickname: "Trails Coffee",
  errored: false,
  ...
}
```

**Decision Required**: 
- [ ] Keep Trails Coffee as default mint
- [ ] Use empty default like upstream
- [ ] Change to different default mint

### 3. Bluetooth Mesh Integration (BitChat Protocol)
**Status**: Major feature addition (80+ files)

**What's Added**:
- Complete mesh networking stack (Noise Protocol, GATT, fragmentation)
- Bluetooth ecash transfer service
- Peer discovery and connection management
- Store-and-forward messaging
- Capacitor plugin bridge

**Files**:
- `android/app/src/main/java/me/bitpoints/wallet/mesh/*` - 17 files
- `android/app/src/main/java/me/bitpoints/wallet/protocol/*` - 10 files  
- `src/stores/bluetooth.ts` - Bluetooth store
- `src/components/NearbyContactsDialog.vue` - UI component
- Many more...

**Decision Required**:
- [ ] KEEP - This is your unique feature, preserve it

### 4. Welcome/Onboarding Flow
**Status**: Simplified in your version

**Your Changes**:
- Skipped seed phrase validation on startup
- Simplified welcome slides (2 slides vs 6 in upstream)
- Removed onboarding path selection

**Decision Required**:
- [ ] Keep simplified welcome flow
- [ ] Merge upstream's improved onboarding

### 5. Mint Management Enhancements
**Status**: Error handling improvements

**Your Changes**:
- Added try-catch error handling in balance calculations
- Added mint initialization checks
- Improved error messages

**Files Modified**:
- `src/stores/mints.ts` - Error handling in `totalUnitBalance`, `activeBalance`
- `src/pages/WalletPage.vue` - Mint initialization validation

**Decision Required**:
- [ ] Keep error handling improvements
- [ ] Merge upstream mint management features

### 6. Settings Changes
**Status**: Some defaults changed

**Your Changes**:
- Nostr mint backup enabled: `true` → `false`
- Welcome flow expanded by default: `true` → `false`
- Removed one default Nostr relay

**Files Modified**:
- `src/stores/settings.ts`
- `src/stores/ui.ts`

**Decision Required**:
- [ ] Keep your default settings
- [ ] Use upstream defaults

### 7. Network Security
**Status**: Added cleartext traffic restriction

**Files Added**:
- `android/app/src/main/res/xml/network_security_config.xml`

**Decision Required**:
- [ ] Keep network security config
- [ ] Remove (upstream doesn't have this)

### 8. Store Differences Summary

| File | Bitpoints Changes | Upstream | Status |
|------|------------------|----------|--------|
| `mints.ts` | Default mint, error handling | No default mint | KEEP |
| `wallet.ts` | Auto-claim token handling | Manual only | KEEP |
| `ui.ts` | Points branding, hide balance by default | Satoshis branding | KEEP |
| `bluetooth.ts` | Entire new store | Doesn't exist | KEEP |
| `npubcash.ts` | Domain change | Original domain | KEEP |
| `restore.ts` | Simplified error handling | More verbose | CONFLICT |
| `settings.ts` | Different defaults | Original defaults | DECIDE |
| `receiveTokensStore.ts` | Auto-claim integration | Manual only | KEEP |
| `welcome.ts` | Simplified flow | Full onboarding | CONFLICT |

## Recommended Merge Strategy

### PHASE 1: Safely Merge Non-Conflicting Updates
Merge these for compatibility:
- Dependencies updates (`package.json`)
- TypeScript type improvements
- Bug fixes in non-modified files
- Translation updates
- Documentation updates

### PHASE 2: Review Conflicting Stores
These need manual review:
- `src/stores/mints.ts` - Balance calculation improvements
- `src/stores/wallet.ts` - Payment flow changes  
- `src/stores/restore.ts` - Restore error handling
- `src/stores/welcome.ts` - Onboarding flow
- `src/stores/settings.ts` - Default values

### PHASE 3: Preserve Unique Features
Never overwrite these:
- All `android/app/src/main/java/me/bitpoints/wallet/mesh/*` files
- All `android/app/src/main/java/me/bitpoints/wallet/protocol/*` files
- `src/stores/bluetooth.ts`
- `src/components/NearbyContactsDialog.vue`
- `src/components/EcashClaimNotification.vue`
- Branding terminology changes

## Your Decision Checklist

Please mark your choices:

**Branding**:
- [ ] Keep "Points" terminology throughout
- [ ] Switch back to "Satoshis"

**Default Mint**:
- [ ] Keep Trails Coffee as default
- [ ] Use empty default (user must add mint)

**Mint Management**:
- [ ] Merge upstream improvements with your error handling
- [ ] Keep your version only

**Welcome Flow**:
- [ ] Keep simplified 2-slide flow
- [ ] Merge upstream's full onboarding

**Settings Defaults**:
- [ ] Keep your defaults
- [ ] Use upstream defaults
- [ ] Mix (specify which)

**Network Security**:
- [ ] Keep strict security config
- [ ] Remove config file

**Error Handling**:
- [ ] Keep your try-catch improvements
- [ ] Merge upstream error handling

**Bluetooth Integration**:
- [ ] KEEP ALL - This is your core unique feature (recommended)

---

## Next Steps After Your Decisions

1. Create a merge branch
2. Merge upstream changes selectively
3. Resolve conflicts preserving your unique features
4. Test thoroughly
5. Create final tag

