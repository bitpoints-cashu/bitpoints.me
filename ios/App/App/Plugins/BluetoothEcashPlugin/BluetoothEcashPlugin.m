#import <Capacitor/Capacitor.h>

CAP_PLUGIN(BluetoothEcashPlugin, "BluetoothEcash",
    CAP_PLUGIN_METHOD(startService, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(stopService, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(sendToken, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getActivePeers, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getUnclaimedTokens, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(markTokenClaimed, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setNickname, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getNickname, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(isBluetoothEnabled, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(requestBluetoothEnable, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(requestPermissions, CAPPluginReturnPromise);
)
