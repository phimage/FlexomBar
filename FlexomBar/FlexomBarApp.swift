import SwiftUI

@main
struct FlexomBarApp: App {
    @State private var store = FlexomStore.shared

    init() {
        // Connect at launch (not on first menu open), so Siri intents that
        // launch the app in the background find a ready session.
        Task { @MainActor in
            await FlexomStore.shared.autoConnect()
        }
    }

    var body: some Scene {
        MenuBarExtra("Flexom", systemImage: "house.fill") {
            MenuContentView()
                .environment(store)
                .task {
                    await store.autoConnect()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
