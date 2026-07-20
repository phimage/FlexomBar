import AppIntents
import SwiftUI
import WidgetKit

/// One timeline entry: the current state of the configured light.
struct LightEntry: TimelineEntry {
    let date: Date
    let light: SharedLight?
    let isConfigured: Bool
}

/// Feeds the widget from the App Group snapshot; no network access here.
struct LightProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LightEntry {
        LightEntry(date: .now, light: nil, isConfigured: false)
    }

    func snapshot(for configuration: SelectLightIntent, in context: Context) async -> LightEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectLightIntent, in context: Context) async -> Timeline<LightEntry> {
        // The app reloads timelines on every state change; refresh hourly as a
        // fallback in case the app is not running.
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(3600)))
    }

    private func entry(for configuration: SelectLightIntent) -> LightEntry {
        let id = configuration.light?.id
        let light = SharedStore.lights.first { $0.id == id }
        return LightEntry(date: .now, light: light, isConfigured: id != nil)
    }
}

struct LightWidgetView: View {
    var entry: LightEntry

    var body: some View {
        if let light = entry.light {
            Button(intent: ToggleLightWidgetIntent(lightID: light.id, turnOn: !light.isOn)) {
                VStack(spacing: 6) {
                    Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.largeTitle)
                        .foregroundStyle(light.isOn ? .yellow : .secondary)
                    Text(light.label)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "lightbulb.slash")
                Text(placeholderText)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var placeholderText: String {
        entry.isConfigured
            ? "Lumière indisponible"
            : "Appui long → Modifier le widget pour choisir une lumière"
    }
}

struct LightWidget: Widget {
    let kind = "com.phimage.FlexomBar.LightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLightIntent.self, provider: LightProvider()) { entry in
            LightWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Lumière Flexom")
        .description("Allume ou éteint une lumière d'un simple tap.")
        .supportedFamilies([.systemSmall])
    }
}
