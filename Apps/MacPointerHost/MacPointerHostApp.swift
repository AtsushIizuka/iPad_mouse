import SharedCore
import SwiftUI

@main
struct MacPointerHostApp: App {
    @StateObject private var shortcutStore: GestureShortcutStore
    @StateObject private var viewModel: MacHostViewModel

    init() {
        let shortcutStore = GestureShortcutStore()
        _shortcutStore = StateObject(wrappedValue: shortcutStore)
        _viewModel = StateObject(wrappedValue: MacHostViewModel(shortcutStore: shortcutStore))
    }

    var body: some Scene {
        MenuBarExtra("MacPointerHost", systemImage: viewModel.peerName == nil ? "cursorarrow.rays" : "cursorarrow.motionlines") {
            MacPointerHostMenu(viewModel: viewModel, shortcutStore: shortcutStore)
                .frame(minWidth: 360, idealWidth: 360, maxWidth: 360, minHeight: 520, alignment: .topLeading)
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MacPointerHostMenu: View {
    @ObservedObject var viewModel: MacHostViewModel
    @ObservedObject var shortcutStore: GestureShortcutStore

    private let editableGestures: [GestureKind] = [
        .pageBack,
        .pageForward,
        .missionControl,
        .appExpose,
        .spaceLeft,
        .spaceRight,
        .launchpad,
        .showDesktop,
        .zoomIn,
        .zoomOut,
        .smartZoom,
        .rotateLeft,
        .rotateRight
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Mac Pointer Host")
                    .font(.headline)
                Text(viewModel.connectionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let peerName = viewModel.peerName {
                    Text("\(peerName) に接続しています")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("権限")
                    .font(.subheadline.weight(.semibold))

                Label(
                    viewModel.hasAccessibilityPermission ? "アクセシビリティ許可済み" : "アクセシビリティの許可が必要です",
                    systemImage: viewModel.hasAccessibilityPermission ? "checkmark.shield" : "exclamationmark.triangle"
                )
                .foregroundStyle(viewModel.hasAccessibilityPermission ? .green : .orange)

                Text(viewModel.lastEventText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("許可ダイアログを開く") {
                        viewModel.requestAccessibilityPermission()
                    }

                    Button("設定を開く") {
                        viewModel.openAccessibilitySettings()
                    }

                    Button("再接続") {
                        viewModel.reconnect()
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("ジェスチャー割り当て")
                    .font(.subheadline.weight(.semibold))

                ForEach(editableGestures, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.displayName)
                            .font(.caption.weight(.medium))
                        Picker(kind.displayName, selection: shortcutStore.selectionBinding(for: kind)) {
                            ForEach(ShortcutPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}
