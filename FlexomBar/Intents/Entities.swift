import AppIntents
import Foundation

/// A light, as Siri and Shortcuts see it.
struct LightEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lumière")
    static let defaultQuery = LightEntityQuery()

    let id: String
    let label: String
    let room: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(label)",
            subtitle: room.map { "\($0)" }
        )
    }
}

struct LightEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LightEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [LightEntity] {
        try await allEntities().filter {
            $0.label.localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [LightEntity] {
        try await allEntities()
    }

    @MainActor
    private func allEntities() async throws -> [LightEntity] {
        let store = FlexomStore.shared
        let lights = try await store.lightsSnapshot()
        return lights.map { light in
            LightEntity(id: light.id, label: light.label, room: store.roomLabel(light.roomID))
        }
    }
}

/// A shutter ("volet"), as Siri and Shortcuts see it.
struct ShutterEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Volet")
    static let defaultQuery = ShutterEntityQuery()

    let id: String
    let label: String
    let room: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(label)",
            subtitle: room.map { "\($0)" }
        )
    }
}

struct ShutterEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ShutterEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ShutterEntity] {
        try await allEntities().filter {
            $0.label.localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [ShutterEntity] {
        try await allEntities()
    }

    @MainActor
    private func allEntities() async throws -> [ShutterEntity] {
        let store = FlexomStore.shared
        let shutters = try await store.shuttersSnapshot()
        return shutters.map { shutter in
            ShutterEntity(id: shutter.id, label: shutter.label, room: store.roomLabel(shutter.roomID))
        }
    }
}

/// A room, used to scope the group intents.
struct RoomEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Pièce")
    static let defaultQuery = RoomEntityQuery()

    let id: String
    let label: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)")
    }
}

struct RoomEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [RoomEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [RoomEntity] {
        try await allEntities().filter {
            $0.label.localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [RoomEntity] {
        try await allEntities()
    }

    private func allEntities() async throws -> [RoomEntity] {
        let rooms = try await FlexomStore.shared.roomsSnapshot()
        return rooms.map { RoomEntity(id: $0.id, label: $0.label) }
    }
}
