import CoreGraphics
import Foundation
import SharedCore
import SwiftUI

enum SecondaryClickMode: String, Codable, CaseIterable, Identifiable {
    case twoFingerTap
    case bottomRightTap
    case bottomLeftTap
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoFingerTap:
            return "2本指タップ"
        case .bottomRightTap:
            return "右下隅"
        case .bottomLeftTap:
            return "左下隅"
        case .off:
            return "無効"
        }
    }
}

@MainActor
final class TrackpadPreferences: ObservableObject {
    private struct PersistedState: Codable {
        var trackingSpeed: Double = 1.35
        var tapToClick: Bool = true
        var secondaryClickMode: SecondaryClickMode = .twoFingerTap
        var naturalScroll: Bool = true
        var swipeBetweenPages: Bool = true
        var zoomEnabled: Bool = true
        var smartZoomEnabled: Bool = true
        var rotateEnabled: Bool = true
        var missionControlEnabled: Bool = true
        var appExposeEnabled: Bool = true
        var swipeBetweenSpacesEnabled: Bool = true
        var launchpadEnabled: Bool = true
        var showDesktopEnabled: Bool = true
        var threeFingerDragEnabled: Bool = false
    }

    private static let storageKey = "TrackpadPreferences.v1"
    private let userDefaults: UserDefaults

    @Published var trackingSpeed: Double { didSet { persist() } }
    @Published var tapToClick: Bool { didSet { persist() } }
    @Published var secondaryClickMode: SecondaryClickMode { didSet { persist() } }
    @Published var naturalScroll: Bool { didSet { persist() } }
    @Published var swipeBetweenPages: Bool { didSet { persist() } }
    @Published var zoomEnabled: Bool { didSet { persist() } }
    @Published var smartZoomEnabled: Bool { didSet { persist() } }
    @Published var rotateEnabled: Bool { didSet { persist() } }
    @Published var missionControlEnabled: Bool { didSet { persist() } }
    @Published var appExposeEnabled: Bool { didSet { persist() } }
    @Published var swipeBetweenSpacesEnabled: Bool { didSet { persist() } }
    @Published var launchpadEnabled: Bool { didSet { persist() } }
    @Published var showDesktopEnabled: Bool { didSet { persist() } }
    @Published var threeFingerDragEnabled: Bool { didSet { persist() } }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let state = Self.load(from: userDefaults)
        trackingSpeed = state.trackingSpeed
        tapToClick = state.tapToClick
        secondaryClickMode = state.secondaryClickMode
        naturalScroll = state.naturalScroll
        swipeBetweenPages = state.swipeBetweenPages
        zoomEnabled = state.zoomEnabled
        smartZoomEnabled = state.smartZoomEnabled
        rotateEnabled = state.rotateEnabled
        missionControlEnabled = state.missionControlEnabled
        appExposeEnabled = state.appExposeEnabled
        swipeBetweenSpacesEnabled = state.swipeBetweenSpacesEnabled
        launchpadEnabled = state.launchpadEnabled
        showDesktopEnabled = state.showDesktopEnabled
        threeFingerDragEnabled = state.threeFingerDragEnabled
    }

    private static func load(from userDefaults: UserDefaults) -> PersistedState {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            return PersistedState()
        }

        return state
    }

    private func persist() {
        let state = PersistedState(
            trackingSpeed: trackingSpeed,
            tapToClick: tapToClick,
            secondaryClickMode: secondaryClickMode,
            naturalScroll: naturalScroll,
            swipeBetweenPages: swipeBetweenPages,
            zoomEnabled: zoomEnabled,
            smartZoomEnabled: smartZoomEnabled,
            rotateEnabled: rotateEnabled,
            missionControlEnabled: missionControlEnabled,
            appExposeEnabled: appExposeEnabled,
            swipeBetweenSpacesEnabled: swipeBetweenSpacesEnabled,
            launchpadEnabled: launchpadEnabled,
            showDesktopEnabled: showDesktopEnabled,
            threeFingerDragEnabled: threeFingerDragEnabled
        )

        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}

@MainActor
final class TouchpadViewModel: ObservableObject {
    @Published private(set) var connectionText = "Macを探しています"
    @Published private(set) var helperText = "Mac で MacPointerHost を開くと接続できます。"

    let preferences: TrackpadPreferences
    private let transport: any TransportClient

    init(
        preferences: TrackpadPreferences = TrackpadPreferences(),
        transport: any TransportClient = PeerTransportClient(role: .controller)
    ) {
        self.preferences = preferences
        self.transport = transport
        self.transport.onStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.handle(status: status)
            }
        }
        self.transport.connect()
    }

    func reconnect() {
        transport.disconnect()
        transport.connect()
    }

    func sendMove(dx: CGFloat, dy: CGFloat) {
        let speed = CGFloat(preferences.trackingSpeed)
        let scaledDX = Float(Self.accelerate(dx) * speed)
        let scaledDY = Float(Self.accelerate(dy) * speed)
        try? transport.send(.pointerMove(dx: scaledDX, dy: scaledDY, ts: Self.timestamp()))
    }

    // Non-linear pointer acceleration: movements below the threshold stay linear for
    // fine-grained control; larger movements gain extra speed for quick screen traversal,
    // matching the feel of a hardware Magic Trackpad.
    private static func accelerate(_ value: CGFloat) -> CGFloat {
        let sign: CGFloat = value < 0 ? -1 : 1
        let magnitude = abs(value)
        let threshold: CGFloat = 2.5
        guard magnitude > threshold else { return value }
        let excess = magnitude - threshold
        return sign * (threshold + excess * (1.0 + excess * 0.12))
    }

    func sendButton(_ button: PointerButton, phase: ButtonPhase, clickCount: Int = 1) {
        try? transport.send(.button(button: button, phase: phase, clickCount: clickCount, ts: Self.timestamp()))
    }

    func sendClick(_ button: PointerButton, clickCount: Int = 1) {
        sendButton(button, phase: .down, clickCount: clickCount)
        sendButton(button, phase: .up, clickCount: clickCount)
    }

    func sendDoublePrimaryClick() {
        sendClick(.left, clickCount: 1)
        sendClick(.left, clickCount: 2)
    }

    func sendScroll(dx: CGFloat, dy: CGFloat, phase: SharedCore.ScrollPhase) {
        let directionMultiplier: CGFloat = preferences.naturalScroll ? 1 : -1
        let scrollDX = Float(dx * 3 * directionMultiplier)
        let scrollDY = Float(-dy * 3 * directionMultiplier)
        try? transport.send(.scroll(dx: scrollDX, dy: scrollDY, phase: phase, ts: Self.timestamp()))
    }

    func sendGesture(_ kind: GestureKind) {
        try? transport.send(.gesture(kind: kind, ts: Self.timestamp()))
    }

    private static func timestamp() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }

    private func handle(status: ConnectionStatus) {
        switch status {
        case .idle:
            connectionText = "待機中"
            helperText = "Mac の準備ができたら「再接続」を押してください。"
        case .discovering:
            connectionText = "Macを探しています"
            helperText = "Mac で MacPointerHost を開くと接続できます。"
        case .connecting:
            connectionText = "接続中"
            helperText = "接続リクエストを送信しました。"
        case let .connected(peerName):
            connectionText = "接続済み"
            helperText = "\(peerName) に入力を送信しています。"
        case let .failed(message):
            connectionText = "接続エラー"
            helperText = message
        }
    }
}
