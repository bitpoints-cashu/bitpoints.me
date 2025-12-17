import SwiftUI
import SharedNostrCore

@main
struct BitpointsWatchApp: App {
    @StateObject private var viewModel = QRViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}

