import SwiftUI

/// Root of the menu bar panel: login form or the device list.
struct MenuContentView: View {
    @Environment(FlexomStore.self) private var store

    var body: some View {
        Group {
            switch store.status {
            case .loggedOut, .connecting:
                LoginView()
            case .connected:
                DeviceListView()
            case .failed:
                VStack(spacing: 12) {
                    if case let .failed(message) = store.status {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                    }
                    HStack {
                        Button("Réessayer") {
                            Task { await store.autoConnect() }
                        }
                        Button("Changer de compte") {
                            Task { await store.logout() }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 340)
    }
}
