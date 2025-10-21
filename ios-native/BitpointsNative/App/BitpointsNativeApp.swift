import SwiftUI

@main
struct BitpointsNativeApp: App {
    @StateObject private var bluetoothService = BluetoothEcashService()
    @StateObject private var webViewBridge = WebViewBridge()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothService)
                .environmentObject(webViewBridge)
                .onAppear {
                    // Initialize the bridge connection
                    webViewBridge.bluetoothService = bluetoothService
                    
                    // Request Bluetooth permissions on app launch
                    bluetoothService.requestPermissions { result in
                        switch result {
                        case .success:
                            print("🔵 Bluetooth permissions granted")
                        case .failure(let error):
                            print("🔵 Bluetooth permissions failed: \(error.localizedDescription)")
                        }
                    }
                }
        }
    }
}
