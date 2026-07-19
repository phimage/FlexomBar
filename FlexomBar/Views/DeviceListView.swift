import AppKit
import SwiftUI

/// The connected panel: room filter, lights and shutters grouped by room.
///
/// Deliberately built on plain (non-lazy) stacks: `MenuBarExtra` windows are
/// known to leave lazily-laid-out content invisible, and an apartment's worth
/// of devices does not need laziness.
struct DeviceListView: View {
    @Environment(FlexomStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("Pièce", selection: $store.roomFilter) {
                    Text("Toutes les pièces").tag(String?.none)
                    ForEach(store.rooms) { room in
                        Text(room.label).tag(String?.some(room.id))
                    }
                }
                .labelsHidden()

                Spacer()

                Menu {
                    Button("Actualiser") {
                        Task { await store.refresh() }
                    }
                    Button("Copier le diagnostic") {
                        copyDiagnostic()
                    }
                    Divider()
                    Button("Se déconnecter") {
                        Task { await store.logout() }
                    }
                    Button("Quitter FlexomBar") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleRooms) { room in
                        sectionHeader(room.label)
                        ForEach(lights(in: room.id)) { light in
                            LightRow(light: light)
                        }
                        ForEach(shutters(in: room.id)) { shutter in
                            ShutterRow(shutter: shutter)
                        }
                    }

                    if store.roomFilter == nil, !unassignedLights.isEmpty || !unassignedShutters.isEmpty {
                        sectionHeader("Autres")
                        ForEach(unassignedLights) { light in
                            LightRow(light: light)
                        }
                        ForEach(unassignedShutters) { shutter in
                            ShutterRow(shutter: shutter)
                        }
                    }

                    if store.lights.isEmpty, store.shutters.isEmpty {
                        Text("Aucune lumière ni volet reconnu.\nUtilise « Copier le diagnostic » (⚙) pour investiguer.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .padding()
                    }
                }
                .padding(.vertical, 8)
                .frame(width: 340, alignment: .leading)
            }
            // MenuBarExtra windows give scroll views no ideal height, so an
            // unconstrained ScrollView collapses to nothing; size it from the
            // content, capped, and let it scroll past the cap.
            .frame(height: listHeight)

            Divider()

            Text("\(store.lights.count) lumière(s) · \(store.shutters.count) volet(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .onAppear { store.startEventLoop() }
    }

    /// Estimated content height: rows are ~30 pt, a position slider adds ~24,
    /// headers ~26. Overestimating wastes a little space; underestimating just
    /// scrolls, so precision does not matter much.
    private var listHeight: CGFloat {
        var height: CGFloat = 16

        var rooms: [(lights: [LightControl], shutters: [ShutterControl])] =
            visibleRooms.map { (lights(in: $0.id), shutters(in: $0.id)) }
        if store.roomFilter == nil, !unassignedLights.isEmpty || !unassignedShutters.isEmpty {
            rooms.append((unassignedLights, unassignedShutters))
        }

        for (roomLights, roomShutters) in rooms {
            height += 26
            height += roomLights.reduce(0) { $0 + ($1.brightness != nil ? 54 : 30) }
            height += roomShutters.reduce(0) { $0 + ($1.canSetClosure ? 54 : 30) }
        }

        if store.lights.isEmpty, store.shutters.isEmpty {
            height += 80
        }

        return min(max(height, 80), 480)
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.caption.smallCaps())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private func copyDiagnostic() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.diagnosticSummary(), forType: .string)
    }

    /// Rooms that still have something to show after the filter.
    private var visibleRooms: [Room] {
        let populated = store.rooms.filter { room in
            !lights(in: room.id).isEmpty || !shutters(in: room.id).isEmpty
        }
        guard let filter = store.roomFilter else { return populated }
        return populated.filter { $0.id == filter }
    }

    private var unassignedLights: [LightControl] {
        store.lights.filter { $0.roomID == nil }
    }

    private var unassignedShutters: [ShutterControl] {
        store.shutters.filter { $0.roomID == nil }
    }

    private func lights(in roomID: String) -> [LightControl] {
        store.lights.filter { $0.roomID == roomID }
    }

    private func shutters(in roomID: String) -> [ShutterControl] {
        store.shutters.filter { $0.roomID == roomID }
    }
}

/// One light: toggle plus, when dimmable, a brightness slider.
struct LightRow: View {
    @Environment(FlexomStore.self) private var store
    let light: LightControl

    @State private var brightness: Double = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 2) {
            Toggle(isOn: Binding(
                get: { light.isOn },
                set: { newValue in
                    Task { await store.setLight(light.id, on: newValue) }
                }
            )) {
                Label(light.label, systemImage: light.isOn ? "lightbulb.fill" : "lightbulb")
                    .foregroundStyle(light.available ? .primary : .secondary)
                Spacer()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!light.available)

            if light.brightness != nil {
                Slider(value: $brightness, in: 0...100, step: 5) { editing in
                    isDragging = editing
                    if !editing {
                        Task { await store.setBrightness(light.id, Int(brightness)) }
                    }
                }
                .controlSize(.small)
                .disabled(!light.available)
            }
        }
        .padding(.horizontal, 12)
        .onAppear { brightness = Double(light.brightness ?? 0) }
        .onChange(of: light.brightness) { _, newValue in
            if !isDragging {
                brightness = Double(newValue ?? 0)
            }
        }
    }
}

/// One shutter: open/stop/close buttons plus, when supported, a position slider.
struct ShutterRow: View {
    @Environment(FlexomStore.self) private var store
    let shutter: ShutterControl

    @State private var closure: Double = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Label(shutter.label, systemImage: iconName)
                    .foregroundStyle(shutter.available ? .primary : .secondary)

                Spacer()

                Button {
                    Task { await store.openShutter(shutter.id) }
                } label: {
                    Image(systemName: "arrow.up")
                }
                .help("Ouvrir")

                if shutter.canStop {
                    Button {
                        Task { await store.stopShutter(shutter.id) }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("Stop")
                }

                Button {
                    Task { await store.closeShutter(shutter.id) }
                } label: {
                    Image(systemName: "arrow.down")
                }
                .help("Fermer")
            }
            .controlSize(.small)
            .disabled(!shutter.available)

            if shutter.canSetClosure {
                Slider(value: $closure, in: 0...100, step: 5) { editing in
                    isDragging = editing
                    if !editing {
                        Task { await store.setShutterClosure(shutter.id, Int(closure)) }
                    }
                }
                .controlSize(.small)
                .disabled(!shutter.available)
                .help("0 % = ouvert, 100 % = fermé")
            }
        }
        .padding(.horizontal, 12)
        .onAppear { closure = Double(shutter.closure ?? 0) }
        .onChange(of: shutter.closure) { _, newValue in
            if !isDragging {
                closure = Double(newValue ?? 0)
            }
        }
    }

    private var iconName: String {
        let closed = (shutter.closure ?? 0) >= 95
        return closed ? "blinds.horizontal.closed" : "blinds.horizontal.open"
    }
}
