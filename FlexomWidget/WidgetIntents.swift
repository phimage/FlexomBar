import AppIntents
import OverkizAPI
import WidgetKit

/// Configuration for a light widget instance: which light it controls.
struct SelectLightIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choisir la lumière"
    static let description = IntentDescription("Sélectionne la lumière contrôlée par ce widget.")

    @Parameter(title: "Lumière")
    var light: WidgetLightEntity?
}

/// Toggles a light from the widget, running in the widget process.
///
/// Flips the shared snapshot first for instant feedback, then authenticates
/// with the mirrored credentials and sends the command to Flexom.
struct ToggleLightWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Basculer la lumière"

    @Parameter(title: "Light")
    var lightID: String

    @Parameter(title: "On")
    var turnOn: Bool

    init() {}

    init(lightID: String, turnOn: Bool) {
        self.lightID = lightID
        self.turnOn = turnOn
    }

    func perform() async throws -> some IntentResult {
        // Optimistic local flip so the widget updates before the round-trip.
        SharedStore.setLightState(lightID, isOn: turnOn)
        WidgetCenter.shared.reloadAllTimelines()

        guard let credentials = SharedStore.credentials else {
            throw FlexomWidgetError.notConfigured
        }

        let client = try OverkizClient(
            server: .flexom,
            credentials: UsernamePasswordCredentials(
                username: credentials.username,
                password: credentials.password
            )
        )

        do {
            try await client.login(registerEventListener: false)
            try await client.executeActionGroup(
                actions: [Action(deviceURL: lightID, command: Command(turnOn ? .on : .off))],
                label: "FlexomBar Widget"
            )
        } catch {
            await client.close()
            // Roll the optimistic flip back on failure.
            SharedStore.setLightState(lightID, isOn: !turnOn)
            WidgetCenter.shared.reloadAllTimelines()
            throw error
        }

        await client.close()
        return .result()
    }
}

/// Errors the widget can surface to the user.
enum FlexomWidgetError: Error, CustomLocalizedStringResourceConvertible {
    case notConfigured

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notConfigured:
            return "Ouvre FlexomBar et connecte-toi d'abord."
        }
    }
}
