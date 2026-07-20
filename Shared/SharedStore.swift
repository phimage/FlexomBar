import Foundation

/// Flexom credentials mirrored into the App Group so the widget process can
/// authenticate. The canonical copy stays in the app's Keychain; this mirror
/// exists only for cross-process sharing and is cleared on logout.
struct SharedCredentials: Codable, Sendable, Hashable {
    let username: String
    let password: String
}

/// A light as the widget needs it: enough to display and to toggle.
struct SharedLight: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let label: String
    let room: String?
    let isOn: Bool
    let dimmable: Bool
}

/// The whole payload shared between the app and the widget.
struct SharedSnapshot: Codable, Sendable {
    var credentials: SharedCredentials?
    var lights: [SharedLight]

    static let empty = SharedSnapshot(credentials: nil, lights: [])
}

/// A file-backed bridge between the menu-bar app and the widget extension.
///
/// The app writes credentials (on login) and a light snapshot (on every state
/// change); the widget reads both — the snapshot for display without a network
/// call, the credentials only when the user taps a toggle. Backed by a JSON
/// file in the shared App Group container so it works in both sandboxed
/// processes without a Keychain-sharing entitlement.
enum SharedStore {
    /// Must match the `com.apple.security.application-groups` entitlement.
    static let appGroupID = "group.com.phimage.FlexomBar"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("snapshot.json")
    }

    static func load() -> SharedSnapshot {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(SharedSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static var credentials: SharedCredentials? {
        load().credentials
    }

    static var lights: [SharedLight] {
        load().lights
    }

    static func updateLights(_ lights: [SharedLight]) {
        var snapshot = load()
        snapshot.lights = lights
        write(snapshot)
    }

    static func updateCredentials(_ credentials: SharedCredentials?) {
        var snapshot = load()
        snapshot.credentials = credentials
        write(snapshot)
    }

    /// Optimistically flips one light's on/off state, so a widget tap shows
    /// feedback before the network round-trip finishes.
    static func setLightState(_ id: String, isOn: Bool) {
        var snapshot = load()
        snapshot.lights = snapshot.lights.map { light in
            light.id == id
                ? SharedLight(id: light.id, label: light.label, room: light.room, isOn: isOn, dimmable: light.dimmable)
                : light
        }
        write(snapshot)
    }

    static func clear() {
        write(.empty)
    }

    private static func write(_ snapshot: SharedSnapshot) {
        guard let fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
