import CoreGraphics
import Foundation
import SharedCore

@MainActor
final class MacHostViewModel: ObservableObject {
    @Published private(set) var connectionText = "iPadを待っています"
    @Published private(set) var peerName: String?
    @Published private(set) var lastEventText = "まだ入力は届いていません"
    @Published private(set) var hasAccessibilityPermission = false

    let shortcutStore: GestureShortcutStore

    private let transport: any TransportClient
    private let pointerController: PointerController
    private let accessibility = AccessibilityPermissionManager()
    private var permissionTimer: Timer?

    init(
        shortcutStore: GestureShortcutStore = GestureShortcutStore(),
        transport: any TransportClient = PeerTransportClient(role: .host),
        pointerController: PointerController = CoreGraphicsPointerController()
    ) {
        self.shortcutStore = shortcutStore
        self.transport = transport
        self.pointerController = pointerController
        self.hasAccessibilityPermission = accessibility.isTrusted
        self.transport.onStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.handle(status: status)
            }
        }
        self.transport.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.refreshPermissionState()
                self?.handle(event)
            }
        }
        startPermissionPolling()
        self.transport.connect()
    }

    func requestAccessibilityPermission() {
        hasAccessibilityPermission = accessibility.requestPermissionPrompt()
        startPermissionPolling(force: true)
    }

    func openAccessibilitySettings() {
        accessibility.openSettings()
        startPermissionPolling(force: true)
    }

    func refreshPermissionState() {
        hasAccessibilityPermission = accessibility.isTrusted
    }

    func reconnect() {
        transport.disconnect()
        transport.connect()
    }

    private func handle(_ event: InputEvent) {
        guard hasAccessibilityPermission else {
            lastEventText = "アクセシビリティが許可されるまで入力を無視します"
            return
        }

        switch event {
        case let .pointerMove(dx, dy, _):
            pointerController.applyMove(dx: CGFloat(dx), dy: CGFloat(dy))
            lastEventText = "ポインタを移動しました"
        case let .click(button, clickCount, _):
            pointerController.applyButton(button, phase: .down, clickCount: clickCount)
            pointerController.applyButton(button, phase: .up, clickCount: clickCount)
            lastEventText = clickCount > 1 ? "\(button.japaneseLabel)をダブルクリックしました" : "\(button.japaneseLabel)をクリックしました"
        case let .button(button, phase, clickCount, _):
            pointerController.applyButton(button, phase: phase, clickCount: clickCount)
            switch phase {
            case .down:
                lastEventText = clickCount > 1 ? "\(button.japaneseLabel)ボタンをダウンしました" : "\(button.japaneseLabel)ボタンを押しました"
            case .up:
                lastEventText = "\(button.japaneseLabel)ボタンを離しました"
            }
        case let .scroll(dx, dy, phase, _):
            pointerController.applyScroll(dx: CGFloat(dx), dy: CGFloat(dy), phase: phase)
            if abs(dx) > abs(dy) {
                lastEventText = "横スクロール: \(phase.japaneseLabel)"
            } else {
                lastEventText = "縦スクロール: \(phase.japaneseLabel)"
            }
        case let .gesture(kind, _):
            pointerController.applyGestureCommand(kind, shortcut: shortcutStore.binding(for: kind))
            lastEventText = kind.displayName
        }
    }

    private func handle(status: ConnectionStatus) {
        switch status {
        case .idle:
            connectionText = "待機中"
            peerName = nil
        case .discovering:
            connectionText = "iPadを待っています"
            peerName = nil
        case .connecting:
            connectionText = "接続中"
        case let .connected(peerName):
            connectionText = "接続済み"
            self.peerName = peerName
        case let .failed(message):
            connectionText = "接続エラー"
            lastEventText = message
            peerName = nil
        }
        refreshPermissionState()
    }

    private func startPermissionPolling(force: Bool = false) {
        if force {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }

        guard permissionTimer == nil else { return }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionState()
            }
        }
        RunLoop.main.add(permissionTimer!, forMode: .common)
    }
}

private extension PointerButton {
    var japaneseLabel: String {
        switch self {
        case .left:
            return "左"
        case .right:
            return "右"
        }
    }
}

private extension ScrollPhase {
    var japaneseLabel: String {
        switch self {
        case .began:
            return "開始"
        case .changed:
            return "移動中"
        case .ended:
            return "終了"
        }
    }
}
