import Foundation
import Observation
import OverkizAPI
import WidgetKit

/// A room in the setup, derived from the Overkiz place tree.
struct Room: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
}

/// View model for a light.
struct LightControl: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let roomID: String?
    let isOn: Bool
    /// Brightness 0–100, or `nil` when the light is not dimmable.
    let brightness: Int?
    let available: Bool
}

/// View model for a shutter ("volet") or similar covering.
struct ShutterControl: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let roomID: String?
    /// Closure 0 (open) – 100 (closed), or `nil` when unknown.
    let closure: Int?
    let canSetClosure: Bool
    let canStop: Bool
    let available: Bool
}

/// Application state: one Overkiz client bound to the Flexom account, plus the
/// device view models the menu and the App Intents read.
@MainActor
@Observable
final class FlexomStore {
    static let shared = FlexomStore()

    enum Status: Equatable {
        case loggedOut
        case connecting
        case connected
        case failed(String)
    }

    private(set) var status: Status = .loggedOut
    private(set) var rooms: [Room] = []
    private(set) var lights: [LightControl] = []
    private(set) var shutters: [ShutterControl] = []
    /// Room to filter the menu on; `nil` shows every room.
    var roomFilter: String?

    /// Device URLs the user pinned as favourites, persisted across launches.
    ///
    /// Surfaced as quick on/off squares at the top of the panel — the menu-bar
    /// answer to "one light square to toggle", which a desktop widget cannot be
    /// under ad-hoc signing (App Groups need a Team ID on macOS).
    private(set) var favorites: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "favorites") ?? []
    )

    /// Username persisted for the next launch; the password lives in the Keychain.
    private(set) var savedUsername: String? = UserDefaults.standard.string(forKey: "username")

    private var client: OverkizClient?
    private var devicesByURL: [String: Device] = [:]
    private var roomLabels: [String: String] = [:]
    /// States updated since the setup was fetched (optimistic writes + events).
    private var liveStates: [String: States] = [:]
    private var eventTask: Task<Void, Never>?

    // UI classes treated as "volets" in the broad sense.
    private static let shutterClasses: Set<UIClass> = [
        .rollerShutter, .adjustableSlatsRollerShutter, .shutter, .swingingShutter,
        .awning, .exteriorScreen, .screen, .exteriorVenetianBlind, .venetianBlind, .curtain
    ]

    // MARK: - Session

    /// Reconnects with stored credentials, if any. Called at launch and on retry.
    func autoConnect() async {
        guard status != .connected, status != .connecting,
              let username = savedUsername,
              let password = Keychain.password(account: username) else {
            return
        }
        await login(username: username, password: password)
    }

    func login(username: String, password: String) async {
        status = .connecting

        do {
            let newClient = try OverkizClient(
                server: .flexom,
                credentials: UsernamePasswordCredentials(username: username, password: password)
            )

            do {
                try await newClient.login(registerEventListener: true)
            } catch {
                await newClient.close()
                throw error
            }
            client = newClient

            UserDefaults.standard.set(username, forKey: "username")
            savedUsername = username
            Keychain.savePassword(password, account: username)
            // Mirror into the App Group so the widget process can authenticate.
            SharedStore.updateCredentials(SharedCredentials(username: username, password: password))

            try await loadSetup()
            status = .connected
            startEventLoop()
        } catch {
            status = .failed(Self.describe(error))
            if let failed = client {
                client = nil
                await failed.close()
            }
        }
    }

    func logout() async {
        stopEventLoop()

        if let username = savedUsername {
            Keychain.deletePassword(account: username)
        }
        UserDefaults.standard.removeObject(forKey: "username")
        savedUsername = nil

        if let client {
            self.client = nil
            await client.close()
        }

        devicesByURL = [:]
        liveStates = [:]
        SharedStore.clear()
        lastSharedLights = []
        rebuild()
        WidgetCenter.shared.reloadAllTimelines()
        status = .loggedOut
    }

    /// Connects with stored credentials when needed. Used by App Intents, which
    /// may run before the user has opened the menu.
    func ensureConnected() async throws -> OverkizClient {
        if status == .connected, let client { return client }

        await autoConnect()

        guard status == .connected, let client else {
            throw FlexomError.notLoggedIn
        }
        return client
    }

    // MARK: - Favourites

    /// Favourite lights, in the panel's display order.
    var favoriteLights: [LightControl] {
        lights.filter { favorites.contains($0.id) }
    }

    func isFavorite(_ id: String) -> Bool {
        favorites.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "favorites")
    }

    // MARK: - Setup

    func refresh() async {
        guard let client else { return }
        do {
            _ = try await client.getSetup(refresh: true)
            try await loadSetup()
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    private func loadSetup() async throws {
        guard let client else { return }

        let setup = try await client.getSetup()

        roomLabels = [:]
        if let root = setup.rootPlace {
            indexPlaces(root)
        }

        devicesByURL = Dictionary(
            setup.devices.map { ($0.deviceURL, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        liveStates = [:]
        rebuild()
    }

    private func indexPlaces(_ place: Place) {
        roomLabels[place.oid] = place.label
        for child in place.subPlaces {
            indexPlaces(child)
        }
    }

    // MARK: - Commands

    func setLight(_ id: String, on: Bool) async {
        await execute(
            id,
            command: Command(on ? .on : .off),
            optimistic: [State(name: OverkizState.coreOnOff.rawValue, type: .string, value: .string(on ? "on" : "off"))]
        )
    }

    func setBrightness(_ id: String, _ value: Int) async {
        let level = max(0, min(100, value))
        await execute(
            id,
            command: Command(.setIntensity, parameters: [.int(level)]),
            optimistic: [
                State(name: OverkizState.coreLightIntensity.rawValue, type: .integer, value: .int(level)),
                State(name: OverkizState.coreOnOff.rawValue, type: .string, value: .string(level > 0 ? "on" : "off"))
            ]
        )
    }

    func openShutter(_ id: String) async {
        guard let command = movementCommand(id, candidates: [.open, .up]) else { return }
        await execute(
            id,
            command: command,
            optimistic: [State(name: OverkizState.coreClosure.rawValue, type: .integer, value: .int(0))]
        )
    }

    func closeShutter(_ id: String) async {
        guard let command = movementCommand(id, candidates: [.close, .down]) else { return }
        await execute(
            id,
            command: command,
            optimistic: [State(name: OverkizState.coreClosure.rawValue, type: .integer, value: .int(100))]
        )
    }

    func stopShutter(_ id: String) async {
        guard let command = movementCommand(id, candidates: [.stop, .my]) else { return }
        await execute(id, command: command, optimistic: [])
    }

    func setShutterClosure(_ id: String, _ value: Int) async {
        let closure = max(0, min(100, value))
        await execute(
            id,
            command: Command(.setClosure, parameters: [.int(closure)]),
            optimistic: [State(name: OverkizState.coreClosure.rawValue, type: .integer, value: .int(closure))]
        )
    }

    /// Runs one command on every device of a group, as a single action group.
    ///
    /// Used by the room-wide Siri intents ("close all the shutters").
    func executeOnAll(_ ids: [String], command: (String) -> Command?, optimistic: [State]) async throws {
        let client = try await ensureConnected()

        let actions = ids.compactMap { id -> Action? in
            guard let command = command(id) else { return nil }
            return Action(deviceURL: id, command: command)
        }
        guard !actions.isEmpty else { return }

        _ = try await client.executeActionGroup(actions: actions, label: "FlexomBar")

        for action in actions {
            applyOptimistic(action.deviceURL, states: optimistic)
        }
        rebuild()
    }

    private func movementCommand(_ id: String, candidates: [OverkizCommand]) -> Command? {
        guard let device = devicesByURL[id],
              let name = device.firstCommand(of: candidates) else {
            return nil
        }
        return Command(name: name)
    }

    private func execute(_ deviceURL: String, command: Command, optimistic: [State]) async {
        do {
            let client = try await ensureConnected()
            _ = try await client.executeActionGroup(
                actions: [Action(deviceURL: deviceURL, command: command)],
                label: "FlexomBar"
            )

            applyOptimistic(deviceURL, states: optimistic)
            rebuild()
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    private func applyOptimistic(_ deviceURL: String, states: [State]) {
        var merged = liveStates[deviceURL] ?? devicesByURL[deviceURL]?.states ?? States()
        for state in states {
            merged[state.name] = state
        }
        liveStates[deviceURL] = merged
    }

    // MARK: - Events

    /// Polls the event listener while the menu is open, so external changes
    /// (wall switches, the Flexom app, schedules) show up live.
    func startEventLoop() {
        guard eventTask == nil, client != nil else { return }

        eventTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollEvents()
                // The API allows one fetch per second; stay under that.
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopEventLoop() {
        eventTask?.cancel()
        eventTask = nil
    }

    private func pollEvents() async {
        guard let client else { return }

        guard let events = try? await client.fetchEvents() else { return }

        var changed = false
        for case let .deviceStateChanged(event) in events {
            applyOptimistic(event.deviceURL, states: event.deviceStates)
            changed = true
        }

        if changed {
            rebuild()
        }
    }

    // MARK: - View models

    private func rebuild() {
        var roomIDs: Set<String> = []
        var newLights: [LightControl] = []
        var newShutters: [ShutterControl] = []

        for device in devicesByURL.values {
            let states = liveStates[device.deviceURL] ?? device.states

            if isLight(device) {
                newLights.append(lightControl(device, states: states))
                if let room = device.placeOID { roomIDs.insert(room) }
            } else if isShutter(device) {
                newShutters.append(shutterControl(device, states: states))
                if let room = device.placeOID { roomIDs.insert(room) }
            }
        }

        lights = newLights.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        shutters = newShutters.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        rooms = roomIDs
            .map { Room(id: $0, label: roomLabels[$0] ?? "Pièce") }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }

        if let filter = roomFilter, !roomIDs.contains(filter) {
            roomFilter = nil
        }

        syncWidgetSnapshot()
    }

    /// Mirrors the current lights into the App Group and reloads the widget,
    /// but only when they actually changed, to avoid churning the file and the
    /// widget on every event poll.
    private var lastSharedLights: [SharedLight] = []

    private func syncWidgetSnapshot() {
        let shared = lights.map { light in
            SharedLight(
                id: light.id,
                label: light.label,
                room: light.roomID.flatMap { roomLabels[$0] },
                isOn: light.isOn,
                dimmable: light.brightness != nil
            )
        }

        guard shared != lastSharedLights else { return }
        lastSharedLights = shared
        SharedStore.updateLights(shared)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Flexom models lights as plain EnOcean on/off actuators (uiClass OnOff,
    // widget StatefulOnOff), not uiClass Light — accept both.
    private static let lightClasses: Set<UIClass> = [.light, .onOff]

    private func isLight(_ device: Device) -> Bool {
        Self.lightClasses.contains(device.uiClass)
            && device.type == .actuator
            && device.supportsAny(commands: [OverkizCommand.on, OverkizCommand.off, OverkizCommand.setIntensity])
    }

    private func isShutter(_ device: Device) -> Bool {
        Self.shutterClasses.contains(device.uiClass)
            && device.supportsAny(commands: [
                OverkizCommand.setClosure, OverkizCommand.open, OverkizCommand.close,
                OverkizCommand.up, OverkizCommand.down
            ])
    }

    private func lightControl(_ device: Device, states: States) -> LightControl {
        let intensity = states[OverkizState.coreLightIntensity]?.intValue
        let onOff = states[OverkizState.coreOnOff]?.stringValue

        return LightControl(
            id: device.deviceURL,
            label: device.label,
            roomID: device.placeOID,
            isOn: onOff.map { $0 == "on" } ?? ((intensity ?? 0) > 0),
            brightness: device.supports(command: OverkizCommand.setIntensity) ? (intensity ?? 0) : nil,
            available: device.available
        )
    }

    private func shutterControl(_ device: Device, states: States) -> ShutterControl {
        ShutterControl(
            id: device.deviceURL,
            label: device.label,
            roomID: device.placeOID,
            closure: states[OverkizState.coreClosure]?.intValue,
            canSetClosure: device.supports(command: OverkizCommand.setClosure),
            canStop: device.supportsAny(commands: [OverkizCommand.stop, OverkizCommand.my]),
            available: device.available
        )
    }

    // MARK: - Intent support

    /// Lights, connecting first if needed. Queries used by Siri call this.
    func lightsSnapshot() async throws -> [LightControl] {
        _ = try await ensureConnected()
        return lights
    }

    /// Shutters, connecting first if needed.
    func shuttersSnapshot() async throws -> [ShutterControl] {
        _ = try await ensureConnected()
        return shutters
    }

    /// Rooms, connecting first if needed.
    func roomsSnapshot() async throws -> [Room] {
        _ = try await ensureConnected()
        return rooms
    }

    func roomLabel(_ id: String?) -> String? {
        id.flatMap { roomLabels[$0] }
    }

    /// A shareable inventory of the setup, for debugging device detection.
    ///
    /// Includes labels and capabilities but deliberately no device URLs or
    /// gateway ids, so it is safe to paste in an issue.
    func diagnosticSummary() -> String {
        var lines: [String] = []
        lines.append("FlexomBar diagnostic — \(Date().formatted(.iso8601))")
        lines.append("status: \(status)")
        lines.append("places: \(roomLabels.count) — rooms with controls: \(rooms.count)")
        lines.append("devices decoded: \(devicesByURL.count) — lights: \(lights.count) — shutters: \(shutters.count)")

        let classCounts = Dictionary(grouping: devicesByURL.values, by: { $0.uiClass.rawValue })
            .map { "\($0.key)×\($0.value.count)" }
            .sorted()
        lines.append("classes: \(classCounts.joined(separator: " "))")
        lines.append("")

        let devices = devicesByURL.values.sorted {
            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
        for device in devices {
            let room = device.placeOID.flatMap { roomLabels[$0] } ?? "sans pièce"
            let commands = device.definition.commands.map(\.commandName).sorted().joined(separator: ",")
            lines.append("• \(device.label) [\(room)]")
            lines.append(
                "  class=\(device.uiClass.rawValue) widget=\(device.widget.rawValue) "
                    + "type=\(device.type.rawValue) available=\(device.available)"
            )
            lines.append("  controllable=\(device.controllableName)")
            lines.append("  commands=\(commands)")
        }

        return lines.joined(separator: "\n")
    }

    /// Command support lookup for the intents, which build room-wide groups.
    func firstCommand(of candidates: [OverkizCommand], for deviceURL: String) -> Command? {
        movementCommand(deviceURL, candidates: candidates)
    }

    private static func describe(_ error: any Error) -> String {
        if let overkiz = error as? OverkizError {
            if overkiz.isBadCredentials {
                return "Identifiants refusés. Vérifie ton e-mail et ton mot de passe Flexom."
            }
            if overkiz.isServiceUnavailable {
                return "Le service Flexom est indisponible pour le moment."
            }
            return overkiz.message
        }
        return error.localizedDescription
    }
}

/// Errors surfaced to Siri and the UI.
enum FlexomError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case deviceNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notLoggedIn:
            return "Connecte-toi d'abord à ton compte Flexom dans FlexomBar."
        case .deviceNotFound:
            return "Cet appareil est introuvable dans ton installation Flexom."
        }
    }
}
