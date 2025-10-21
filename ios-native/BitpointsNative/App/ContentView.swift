import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var bluetoothService: BluetoothEcashService
    @EnvironmentObject var webViewBridge: WebViewBridge
    @State private var webView: WKWebView?
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar showing Bluetooth state
            BluetoothStatusBar()
                .environmentObject(bluetoothService)
            
            // Main WebView container
            if let webView = webView {
                WebViewContainer(webView: webView)
                    .onAppear {
                        webViewBridge.webView = webView
                    }
            } else {
                ProgressView("Loading Bitpoints...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            setupWebView()
        }
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Add message handler for JavaScript to Swift communication
        configuration.userContentController.add(webViewBridge, name: "bluetoothBridge")
        
        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        
        // Load the bundled web app
        if let webappURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "webapp") {
            newWebView.loadFileURL(webappURL, allowingReadAccessTo: webappURL.deletingLastPathComponent())
        } else {
            // Fallback to loading from a URL if bundle not found
            if let url = URL(string: "https://bitpoints.me") {
                newWebView.load(URLRequest(url: url))
            }
        }
        
        webView = newWebView
    }
}

struct BluetoothStatusBar: View {
    @EnvironmentObject var bluetoothService: BluetoothEcashService
    @State private var bluetoothState: String = "Unknown"
    
    var body: some View {
        HStack {
            Image(systemName: bluetoothIcon)
                .foregroundColor(bluetoothColor)
            
            Text("Bluetooth: \(bluetoothState)")
                .font(.caption)
                .foregroundColor(bluetoothColor)
            
            Spacer()
            
            if bluetoothService.isBluetoothEnabled() {
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Not Ready")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .onAppear {
            updateBluetoothState()
        }
    }
    
    private var bluetoothIcon: String {
        if bluetoothService.isBluetoothEnabled() {
            return "bluetooth"
        } else {
            return "bluetooth.slash"
        }
    }
    
    private var bluetoothColor: Color {
        if bluetoothService.isBluetoothEnabled() {
            return .blue
        } else {
            return .red
        }
    }
    
    private func updateBluetoothState() {
        if bluetoothService.isBluetoothEnabled() {
            bluetoothState = "Enabled"
        } else {
            bluetoothState = "Disabled"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BluetoothEcashService())
        .environmentObject(WebViewBridge())
}
