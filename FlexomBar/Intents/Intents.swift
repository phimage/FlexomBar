import AppIntents
import Foundation
import OverkizAPI

// MARK: - Lights

struct TurnOnLightIntent: AppIntent {
    static let title: LocalizedStringResource = "Allumer une lumière"
    static let description = IntentDescription("Allume une lumière Flexom.")

    @Parameter(title: "Lumière")
    var light: LightEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await FlexomStore.shared.setLight(light.id, on: true)
        return .result(dialog: "\(light.label) est allumée.")
    }
}

struct TurnOffLightIntent: AppIntent {
    static let title: LocalizedStringResource = "Éteindre une lumière"
    static let description = IntentDescription("Éteint une lumière Flexom.")

    @Parameter(title: "Lumière")
    var light: LightEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await FlexomStore.shared.setLight(light.id, on: false)
        return .result(dialog: "\(light.label) est éteinte.")
    }
}

struct SetLightBrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Régler la luminosité"
    static let description = IntentDescription("Règle la luminosité d'une lumière Flexom.")

    @Parameter(title: "Lumière")
    var light: LightEntity

    @Parameter(title: "Luminosité (%)")
    var brightness: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await FlexomStore.shared.setBrightness(light.id, brightness)
        return .result(dialog: "\(light.label) à \(brightness) %.")
    }
}

struct TurnOffAllLightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Éteindre toutes les lumières"
    static let description = IntentDescription("Éteint toutes les lumières, ou celles d'une pièce.")

    @Parameter(title: "Pièce")
    var room: RoomEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FlexomStore.shared
        let lights = try await store.lightsSnapshot()
            .filter { room == nil || $0.roomID == room?.id }

        try await store.executeOnAll(
            lights.map(\.id),
            command: { _ in Command(.off) },
            optimistic: [State(name: OverkizState.coreOnOff.rawValue, type: .string, value: .string("off"))]
        )

        let scope = room.map { "de \($0.label) " } ?? ""
        return .result(dialog: "Lumières \(scope)éteintes.")
    }
}

// MARK: - Shutters

struct OpenShutterIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir un volet"
    static let description = IntentDescription("Ouvre un volet Flexom.")

    @Parameter(title: "Volet")
    var shutter: ShutterEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await FlexomStore.shared.openShutter(shutter.id)
        return .result(dialog: "\(shutter.label) s'ouvre.")
    }
}

struct CloseShutterIntent: AppIntent {
    static let title: LocalizedStringResource = "Fermer un volet"
    static let description = IntentDescription("Ferme un volet Flexom.")

    @Parameter(title: "Volet")
    var shutter: ShutterEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await FlexomStore.shared.closeShutter(shutter.id)
        return .result(dialog: "\(shutter.label) se ferme.")
    }
}

struct SetShutterPositionIntent: AppIntent {
    static let title: LocalizedStringResource = "Régler un volet"
    static let description = IntentDescription("Règle la fermeture d'un volet Flexom (0 % = ouvert, 100 % = fermé).")

    @Parameter(title: "Volet")
    var shutter: ShutterEntity

    @Parameter(title: "Fermeture (%)")
    var closure: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await FlexomStore.shared.setShutterClosure(shutter.id, closure)
        return .result(dialog: "\(shutter.label) à \(closure) % de fermeture.")
    }
}

struct OpenAllShuttersIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir tous les volets"
    static let description = IntentDescription("Ouvre tous les volets, ou ceux d'une pièce.")

    @Parameter(title: "Pièce")
    var room: RoomEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FlexomStore.shared
        let shutters = try await store.shuttersSnapshot()
            .filter { room == nil || $0.roomID == room?.id }

        try await store.executeOnAll(
            shutters.map(\.id),
            command: { store.firstCommand(of: [.open, .up], for: $0) },
            optimistic: [State(name: OverkizState.coreClosure.rawValue, type: .integer, value: .int(0))]
        )

        let scope = room.map { "de \($0.label) " } ?? ""
        return .result(dialog: "Volets \(scope)ouverts.")
    }
}

struct CloseAllShuttersIntent: AppIntent {
    static let title: LocalizedStringResource = "Fermer tous les volets"
    static let description = IntentDescription("Ferme tous les volets, ou ceux d'une pièce.")

    @Parameter(title: "Pièce")
    var room: RoomEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FlexomStore.shared
        let shutters = try await store.shuttersSnapshot()
            .filter { room == nil || $0.roomID == room?.id }

        try await store.executeOnAll(
            shutters.map(\.id),
            command: { store.firstCommand(of: [.close, .down], for: $0) },
            optimistic: [State(name: OverkizState.coreClosure.rawValue, type: .integer, value: .int(100))]
        )

        let scope = room.map { "de \($0.label) " } ?? ""
        return .result(dialog: "Volets \(scope)fermés.")
    }
}
