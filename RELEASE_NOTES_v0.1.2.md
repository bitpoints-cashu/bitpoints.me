# Bitpoints v0.1.2 Release Notes

## 🚀 **Streamlined Send & Receive Flow**

### **Receive Flow Improvements**
- **Direct QR Scanner**: "Receive" button now directly opens QR code scanner (no intermediate dialog)
- **Auto-Receive**: Tokens are automatically processed after scanning or pasting
- **Read-Only Token Display**: Prevents keyboard popup when displaying encrypted tokens
- **Lightning as Secondary**: Lightning option available as smaller button within QR scanner
- **Paste Integration**: Seamless clipboard paste functionality

### **Send Flow Improvements**
- **Direct Points Send**: "Send" button now directly opens points send dialog
- **Lightning Switch**: Easy switch to Lightning payment from points send dialog
- **Bidirectional Switching**: Switch between Points and Lightning from both dialogs
- **Streamlined UI**: Cleaner, more intuitive interface

## 🔧 **Bluetooth Token Management**

### **0-Sat Token Handling**
- **Automatic Filtering**: 0-sat tokens are ignored and not processed
- **No Error Notifications**: Eliminates "Token already spent" error messages
- **Silent Cleanup**: Already-spent tokens are silently removed from lists

### **Manual Token Management**
- **"Clear All" Button**: Force clear all unclaimed tokens (red button in notification banner)
- **localStorage Cleanup**: Permanently removes tokens from storage to prevent reappearance
- **Startup Protection**: Automatically clears if too many tokens accumulate (>50)

### **Silent Claim Processing**
- **No Error Popups**: Manual "Claim All" and individual claims work silently
- **Background Processing**: Tokens are processed without user interruption
- **Smart Error Handling**: Distinguishes between real errors and expected "already spent" responses

## 🎨 **UI/UX Enhancements**

### **Notification Banner**
- **Cleaner Design**: Removed large paste button, kept smaller integrated paste
- **Action Buttons**: "Claim All" and "Clear All" buttons for token management
- **Expandable Details**: Show/hide individual token details
- **Better Visual Hierarchy**: Improved button sizing and spacing

### **QR Scanner Interface**
- **Card-Based Design**: Modern card layout with header and actions
- **Integrated Actions**: Paste and Lightning options within scanner view
- **Better Visual Feedback**: Clear success/error states

### **Send/Receive Dialogs**
- **Consistent Switching**: Easy toggle between Points and Lightning
- **Icon Integration**: Clear visual indicators for different payment types
- **Streamlined Flow**: Fewer steps to complete transactions

## 🐛 **Bug Fixes**

### **Token Persistence Issues**
- **localStorage Management**: Fixed tokens reappearing after app restart
- **Memory Leaks**: Prevented accumulation of unclaimed tokens
- **State Synchronization**: Better sync between memory and persistent storage

### **Error Handling**
- **Silent Error Recovery**: Graceful handling of "Token already spent" errors
- **User Experience**: Reduced error notifications for expected scenarios
- **Debug Logging**: Enhanced logging for troubleshooting

### **Bluetooth Stability**
- **Connection Management**: Improved Bluetooth service initialization
- **Token Processing**: More reliable token claiming and cleanup
- **State Management**: Better handling of offline/online transitions

## 🔧 **Technical Improvements**

### **Code Quality**
- **Silent Methods**: Added `claimTokenSilently()` and `autoClaimTokensSilently()`
- **Cleanup Methods**: `clearAllUnclaimedTokens()` and `cleanupUnclaimedTokensOnStartup()`
- **Debug Tools**: Enhanced logging and state inspection methods
- **Error Detection**: Smart detection of "already spent" vs real errors

### **Performance**
- **Faster Processing**: Reduced delays in token processing (200ms vs 500ms)
- **Memory Management**: Better cleanup of processed tokens
- **Startup Optimization**: Faster app initialization with token cleanup

## 📱 **Platform Support**

### **Android**
- **Native Bluetooth**: Full support for Android Bluetooth mesh networking
- **Token Persistence**: Proper handling of native token storage
- **Error Recovery**: Robust error handling for native operations

### **Web/PWA**
- **Web Bluetooth**: Support for desktop Chrome/Edge Web Bluetooth
- **Fallback Handling**: Graceful degradation when Bluetooth unavailable
- **Cross-Platform**: Consistent experience across platforms

## 🎯 **User Experience**

### **Simplified Workflows**
- **One-Click Actions**: Direct access to primary functions
- **Reduced Steps**: Fewer taps to complete transactions
- **Clear Visual Hierarchy**: Intuitive button placement and sizing

### **Error Prevention**
- **Proactive Cleanup**: Automatic removal of problematic tokens
- **Smart Defaults**: Points as default, Lightning as secondary option
- **Silent Processing**: Background handling of routine operations

## 🔄 **Migration Notes**

### **Existing Users**
- **Automatic Cleanup**: App will automatically clean up accumulated tokens on first launch
- **Preserved Settings**: All existing settings and preferences maintained
- **Seamless Upgrade**: No manual intervention required

### **New Users**
- **Streamlined Onboarding**: Faster path to first transaction
- **Clear Defaults**: Points-first approach with easy Lightning access
- **Better Guidance**: More intuitive interface reduces learning curve

---

## 🏷️ **Version Information**
- **Version**: 0.1.2
- **Release Date**: October 19, 2024
- **Platform**: Android, Web/PWA
- **Compatibility**: Android 7.0+, Chrome 80+, Edge 80+

## 📋 **Installation**
- **Android**: Install APK from releases page
- **Web**: Access via browser at bitpoints.me
- **PWA**: Install from browser for offline access

---

*This release focuses on streamlining the user experience while maintaining all existing functionality. The Points-first approach with Lightning as secondary option provides a cleaner, more intuitive interface for both new and experienced users.*
