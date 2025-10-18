package me.bitpoints.wallet;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    private static final String TAG = "MainActivity";
    private static final String BATTERY_OPTIMIZATION_REQUEST = "me.bitpoints.wallet.REQUEST_BATTERY_OPTIMIZATION";
    private static final int CAMERA_PERMISSION_REQUEST = 1001;
    
    private BroadcastReceiver batteryOptimizationReceiver;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Log.i(TAG, "onCreate: Registering BluetoothEcash plugin");
        try {
            registerPlugin(BluetoothEcashPlugin.class);
            Log.i(TAG, "onCreate: BluetoothEcash plugin registered successfully");
        } catch (Exception e) {
            Log.e(TAG, "onCreate: Failed to register BluetoothEcash plugin", e);
        }
        
        // Register battery optimization receiver
        registerBatteryOptimizationReceiver();
        
        super.onCreate(savedInstanceState);
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        if (batteryOptimizationReceiver != null) {
            try {
                unregisterReceiver(batteryOptimizationReceiver);
                Log.d(TAG, "Battery optimization receiver unregistered");
            } catch (Exception e) {
                Log.e(TAG, "Failed to unregister battery optimization receiver", e);
            }
        }
    }
    
    /**
     * Register broadcast receiver for battery optimization requests
     */
    private void registerBatteryOptimizationReceiver() {
        batteryOptimizationReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (BATTERY_OPTIMIZATION_REQUEST.equals(intent.getAction())) {
                    Log.d(TAG, "Battery optimization exemption requested");
                    requestBatteryOptimizationExemption();
                }
            }
        };
        
        IntentFilter filter = new IntentFilter(BATTERY_OPTIMIZATION_REQUEST);
        try {
            // For Android 14+ (SDK 34+), we must specify RECEIVER_NOT_EXPORTED
            // since this is a private app-specific broadcast
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                registerReceiver(batteryOptimizationReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
            } else {
                registerReceiver(batteryOptimizationReceiver, filter);
            }
            Log.d(TAG, "Battery optimization receiver registered");
        } catch (Exception e) {
            Log.e(TAG, "Failed to register battery optimization receiver", e);
        }
    }
    
    /**
     * Request battery optimization exemption
     */
    private void requestBatteryOptimizationExemption() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                intent.setData(Uri.parse("package:" + getPackageName()));
                startActivity(intent);
                Log.d(TAG, "Battery optimization exemption dialog opened");
            } else {
                Log.d(TAG, "Battery optimization not needed on Android < 6.0");
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to open battery optimization settings", e);
        }
    }

    public boolean checkCameraPermission() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
    }

    public void requestCameraPermission() {
        if (!checkCameraPermission()) {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.CAMERA}, CAMERA_PERMISSION_REQUEST);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CAMERA_PERMISSION_REQUEST) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "Camera permission granted");
            } else {
                Log.w(TAG, "Camera permission denied");
            }
        }
    }
}


