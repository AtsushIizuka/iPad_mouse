import Foundation
import SharedCore
import SwiftUI

@main
struct PadTrackApp: App {
    @StateObject private var preferences: TrackpadPreferences
    @StateObject private var viewModel: TouchpadViewModel

    init() {
        let preferences = TrackpadPreferences()
        _preferences = StateObject(wrappedValue: preferences)
        _viewModel = StateObject(wrappedValue: TouchpadViewModel(preferences: preferences))
    }

    var body: some Scene {
        WindowGroup {
            ControllerRootView(viewModel: viewModel, preferences: preferences)
        }
    }
}

private struct ControllerRootView: View {
    @ObservedObject var viewModel: TouchpadViewModel
    @ObservedObject var preferences: TrackpadPreferences
    @State private var isSettingsPresented = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.18, blue: 0.31),
                    Color(red: 0.09, green: 0.10, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                FunctionKeyBar(viewModel: viewModel, isSettingsPresented: $isSettingsPresented)

                TouchpadSurfaceView(
                    configuration: .init(preferences: preferences),
                    onPointerMove: { delta in
                        viewModel.sendMove(dx: delta.x, dy: delta.y)
                    },
                    onButton: { button, phase, clickCount in
                        viewModel.sendButton(button, phase: phase, clickCount: clickCount)
                    },
                    onPrimaryDoubleClick: {
                        viewModel.sendDoublePrimaryClick()
                    },
                    onScroll: { delta, phase in
                        viewModel.sendScroll(dx: delta.x, dy: delta.y, phase: phase)
                    },
                    onGesture: { kind in
                        viewModel.sendGesture(kind)
                    },
                    onNewTouchSequence: {
                        viewModel.resetMovementSmoothing()
                    }
                )
                .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.connectionText)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(viewModel.helperText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(18)
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            PadTrackSettingsView(viewModel: viewModel, preferences: preferences)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct FunctionKeyBar: View {
    @ObservedObject var viewModel: TouchpadViewModel
    @Binding var isSettingsPresented: Bool

    private struct FunctionKey {
        let icon: String
        let label: String
        let kind: GestureKind
    }

    private let keys: [FunctionKey] = [
        FunctionKey(icon: "sun.min",               label: "明るさを下げる",             kind: .brightnessDown),
        FunctionKey(icon: "sun.max",               label: "明るさを上げる",             kind: .brightnessUp),
        FunctionKey(icon: "square.split.2x1",      label: "ミッションコントロール",      kind: .missionControl),
        FunctionKey(icon: "square.grid.3x3.fill",  label: "Launchpad",               kind: .launchpad),
        FunctionKey(icon: "keyboard.chevron.compact.down", label: "キーボードの明るさを下げる", kind: .keyboardBrightnessDown),
        FunctionKey(icon: "keyboard",              label: "キーボードの明るさを上げる",  kind: .keyboardBrightnessUp),
        FunctionKey(icon: "backward.end.fill",     label: "前のトラック",              kind: .mediaPrevious),
        FunctionKey(icon: "playpause.fill",         label: "再生 / 一時停止",           kind: .mediaPlayPause),
        FunctionKey(icon: "forward.end.fill",      label: "次のトラック",              kind: .mediaNext),
        FunctionKey(icon: "speaker.slash.fill",    label: "消音",                     kind: .volumeMute),
        FunctionKey(icon: "speaker.minus.fill",    label: "音量を下げる",              kind: .volumeDown),
        FunctionKey(icon: "speaker.plus.fill",     label: "音量を上げる",              kind: .volumeUp),
    ]

    var body: some View {
        HStack(spacing: 0) {
            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }

            Divider()
                .frame(height: 28)
                .overlay(Color.white.opacity(0.3))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(keys, id: \.kind) { key in
                        Button {
                            viewModel.sendGesture(key.kind)
                        } label: {
                            Image(systemName: key.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .accessibilityLabel(key.label)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 52)
        .background(.ultraThinMaterial.opacity(0.25))
    }
}

private struct PadTrackSettingsView: View {
    @ObservedObject var viewModel: TouchpadViewModel
    @ObservedObject var preferences: TrackpadPreferences

    var body: some View {
        NavigationStack {
            Form {
                Section("ポイントとクリック") {
                    Toggle("タップでクリック", isOn: $preferences.tapToClick)

                    HStack {
                        Text("移動速度")
                        Slider(value: $preferences.trackingSpeed, in: 0.4...2.8)
                        Text(String(format: "%.2f", preferences.trackingSpeed))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44)
                    }

                    Picker("副ボタンのクリック", selection: $preferences.secondaryClickMode) {
                        ForEach(SecondaryClickMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section("スクロールとズーム") {
                    Toggle("ナチュラルスクロール", isOn: $preferences.naturalScroll)
                    Toggle("ページ間をスワイプ", isOn: $preferences.swipeBetweenPages)
                    Toggle("拡大 / 縮小", isOn: $preferences.zoomEnabled)
                    Toggle("スマートズーム", isOn: $preferences.smartZoomEnabled)
                    Toggle("回転", isOn: $preferences.rotateEnabled)
                }

                Section("その他のジェスチャー") {
                    Toggle("Mission Control", isOn: $preferences.missionControlEnabled)
                    Toggle("App Exposé", isOn: $preferences.appExposeEnabled)
                    Toggle("フルスクリーンアプリ間をスワイプ", isOn: $preferences.swipeBetweenSpacesEnabled)
                    Toggle("Launchpad", isOn: $preferences.launchpadEnabled)
                    Toggle("デスクトップを表示", isOn: $preferences.showDesktopEnabled)
                    Toggle("3本指ドラッグ", isOn: $preferences.threeFingerDragEnabled)
                }

                Section("接続") {
                    LabeledContent("状態", value: viewModel.connectionText)
                    Text(viewModel.helperText)
                        .foregroundStyle(.secondary)

                    Button("再接続") {
                        viewModel.reconnect()
                    }
                }

                Section("ジェスチャー一覧") {
                    GestureLine(icon: "cursorarrow.motionlines", text: "1本指ドラッグ: ポインタ移動")
                    GestureLine(icon: "hand.tap", text: "1回タップ: 左クリック")
                    GestureLine(icon: "hand.tap.fill", text: "1本指ダブルタップ: ダブルクリック")
                    GestureLine(icon: "rectangle.and.hand.point.up.left.fill", text: "1本指でタップして保持しながら移動: ドラッグ")
                    GestureLine(icon: "cursorarrow.click.2", text: "2本指タップまたは隅タップ: 副ボタンクリック")
                    GestureLine(icon: "arrow.up.and.down.and.arrow.left.and.right", text: "2本指ドラッグ: スクロール")
                    GestureLine(icon: "arrow.left.and.right.circle", text: "2本指スワイプ: 戻る / 進む")
                    GestureLine(icon: "plus.magnifyingglass", text: "2本指ピンチ / 回転: 拡大縮小 / 回転")
                    GestureLine(icon: "square.stack.3d.up", text: "3本指スワイプ: Mission Control / App Exposé")
                    GestureLine(icon: "rectangle.2.swap", text: "4本指スワイプ / ピンチ: スペース切替 / Launchpad / デスクトップ")
                }
            }
            .navigationTitle("PadTrack設定")
        }
    }
}

private struct GestureLine: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
        }
    }
}
