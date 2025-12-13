import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: QRViewModel

    var body: some View {
        VStack(spacing: 8) {
            if let image = viewModel.qrImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
            } else {
                ProgressView("Preparing QR…")
            }

            VStack(spacing: 4) {
                Text(shortPubkey(viewModel.pubkeyHex))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("Updated \(viewModel.lastUpdated, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }

            Button("Refresh") {
                Task { await viewModel.regenerate() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func shortPubkey(_ pk: String) -> String {
        guard pk.count > 12 else { return pk }
        let prefix = pk.prefix(6)
        let suffix = pk.suffix(6)
        return "\(prefix)…\(suffix)"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: QRViewModel())
    }
}

