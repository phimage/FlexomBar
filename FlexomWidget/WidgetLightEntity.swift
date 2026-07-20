import AppIntents

/// A light the user can assign to a widget instance.
///
/// Sourced entirely from the App Group snapshot the app writes, so picking a
/// light in the widget configuration needs no network access.
struct WidgetLightEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lumière")
    static let defaultQuery = WidgetLightQuery()

    let id: String
    let label: String
    let room: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)", subtitle: room.map { "\($0)" })
    }
}

struct WidgetLightQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetLightEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetLightEntity] {
        all()
    }

    private func all() -> [WidgetLightEntity] {
        SharedStore.lights.map { WidgetLightEntity(id: $0.id, label: $0.label, room: $0.room) }
    }
}
