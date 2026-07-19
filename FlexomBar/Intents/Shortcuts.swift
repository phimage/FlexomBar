import AppIntents

/// The phrases Siri and Spotlight understand out of the box.
///
/// Every phrase must mention the application name; parameterised phrases pull
/// their vocabulary from the entity queries (device labels, room names).
struct FlexomShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnLightIntent(),
            phrases: [
                "Allume \(\.$light) avec \(.applicationName)",
                "Turn on \(\.$light) with \(.applicationName)"
            ],
            shortTitle: "Allumer",
            systemImageName: "lightbulb.fill"
        )

        AppShortcut(
            intent: TurnOffLightIntent(),
            phrases: [
                "Éteins \(\.$light) avec \(.applicationName)",
                "Turn off \(\.$light) with \(.applicationName)"
            ],
            shortTitle: "Éteindre",
            systemImageName: "lightbulb.slash"
        )

        AppShortcut(
            intent: OpenShutterIntent(),
            phrases: [
                "Ouvre \(\.$shutter) avec \(.applicationName)",
                "Open \(\.$shutter) with \(.applicationName)"
            ],
            shortTitle: "Ouvrir un volet",
            systemImageName: "blinds.horizontal.open"
        )

        AppShortcut(
            intent: CloseShutterIntent(),
            phrases: [
                "Ferme \(\.$shutter) avec \(.applicationName)",
                "Close \(\.$shutter) with \(.applicationName)"
            ],
            shortTitle: "Fermer un volet",
            systemImageName: "blinds.horizontal.closed"
        )

        AppShortcut(
            intent: OpenAllShuttersIntent(),
            phrases: [
                "Ouvre les volets avec \(.applicationName)",
                "Ouvre tous les volets avec \(.applicationName)",
                "Open the shutters with \(.applicationName)"
            ],
            shortTitle: "Ouvrir les volets",
            systemImageName: "sun.max"
        )

        AppShortcut(
            intent: CloseAllShuttersIntent(),
            phrases: [
                "Ferme les volets avec \(.applicationName)",
                "Ferme tous les volets avec \(.applicationName)",
                "Close the shutters with \(.applicationName)"
            ],
            shortTitle: "Fermer les volets",
            systemImageName: "moon"
        )

        AppShortcut(
            intent: TurnOffAllLightsIntent(),
            phrases: [
                "Éteins les lumières avec \(.applicationName)",
                "Éteins tout avec \(.applicationName)",
                "Turn off the lights with \(.applicationName)"
            ],
            shortTitle: "Tout éteindre",
            systemImageName: "lightbulb.slash.fill"
        )
    }
}
