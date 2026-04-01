import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import SharedCore
import SwiftUI

enum ShortcutPreset: String, Codable, CaseIterable, Identifiable {
    case none
    case commandLeftBracket
    case commandRightBracket
    case controlUp
    case controlDown
    case controlLeft
    case controlRight
    case launchpad
    case showDesktop
    case zoomIn
    case zoomOut
    case smartZoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "無効"
        case .commandLeftBracket:
            return "Command-["
        case .commandRightBracket:
            return "Command-]"
        case .controlUp:
            return "Control-Up"
        case .controlDown:
            return "Control-Down"
        case .controlLeft:
            return "Control-Left"
        case .controlRight:
            return "Control-Right"
        case .launchpad:
            return "F4"
        case .showDesktop:
            return "F11"
        case .zoomIn:
            return "Command-="
        case .zoomOut:
            return "Command--"
        case .smartZoom:
            return "Command-0"
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .none:
            return nil
        case .commandLeftBracket:
            return CGKeyCode(kVK_ANSI_LeftBracket)
        case .commandRightBracket:
            return CGKeyCode(kVK_ANSI_RightBracket)
        case .controlUp:
            return CGKeyCode(kVK_UpArrow)
        case .controlDown:
            return CGKeyCode(kVK_DownArrow)
        case .controlLeft:
            return CGKeyCode(kVK_LeftArrow)
        case .controlRight:
            return CGKeyCode(kVK_RightArrow)
        case .launchpad:
            return CGKeyCode(kVK_F4)
        case .showDesktop:
            return CGKeyCode(kVK_F11)
        case .zoomIn:
            return CGKeyCode(kVK_ANSI_Equal)
        case .zoomOut:
            return CGKeyCode(kVK_ANSI_Minus)
        case .smartZoom:
            return CGKeyCode(kVK_ANSI_0)
        }
    }

    var flags: CGEventFlags {
        switch self {
        case .none, .launchpad, .showDesktop:
            return []
        case .commandLeftBracket, .commandRightBracket, .zoomIn, .zoomOut, .smartZoom:
            return .maskCommand
        case .controlUp, .controlDown, .controlLeft, .controlRight:
            return .maskControl
        }
    }
}

struct ShortcutBinding: Codable, Equatable {
    var preset: ShortcutPreset

    static let none = ShortcutBinding(preset: .none)
}

@MainActor
final class GestureShortcutStore: ObservableObject {
    private static let storageKey = "GestureShortcutStore.v1"
    private let userDefaults: UserDefaults

    @Published private var bindings: [GestureKind: ShortcutBinding]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if
            let data = userDefaults.data(forKey: Self.storageKey),
            let stored = try? JSONDecoder().decode([String: ShortcutBinding].self, from: data)
        {
            bindings = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
                GestureKind(rawValue: key).map { ($0, value) }
            })
        } else {
            bindings = Self.defaultBindings()
        }

        for kind in GestureKind.allCases where bindings[kind] == nil {
            bindings[kind] = Self.defaultBinding(for: kind)
        }
    }

    func binding(for kind: GestureKind) -> ShortcutBinding {
        bindings[kind] ?? Self.defaultBinding(for: kind)
    }

    func setBinding(_ binding: ShortcutBinding, for kind: GestureKind) {
        bindings[kind] = binding
        persist()
    }

    func selectionBinding(for kind: GestureKind) -> Binding<ShortcutPreset> {
        Binding(
            get: { self.binding(for: kind).preset },
            set: { self.setBinding(ShortcutBinding(preset: $0), for: kind) }
        )
    }

    private func persist() {
        let encoded = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }

    private static func defaultBindings() -> [GestureKind: ShortcutBinding] {
        Dictionary(uniqueKeysWithValues: GestureKind.allCases.map { ($0, defaultBinding(for: $0)) })
    }

    private static func defaultBinding(for kind: GestureKind) -> ShortcutBinding {
        switch kind {
        case .missionControl:
            return ShortcutBinding(preset: .controlUp)
        case .appExpose:
            return ShortcutBinding(preset: .controlDown)
        case .spaceLeft:
            return ShortcutBinding(preset: .controlLeft)
        case .spaceRight:
            return ShortcutBinding(preset: .controlRight)
        case .launchpad:
            return ShortcutBinding(preset: .launchpad)
        case .showDesktop:
            return ShortcutBinding(preset: .showDesktop)
        case .pageBack:
            return ShortcutBinding(preset: .commandLeftBracket)
        case .pageForward:
            return ShortcutBinding(preset: .commandRightBracket)
        case .zoomIn:
            return ShortcutBinding(preset: .zoomIn)
        case .zoomOut:
            return ShortcutBinding(preset: .zoomOut)
        case .smartZoom:
            return ShortcutBinding(preset: .smartZoom)
        case .rotateLeft, .rotateRight:
            return .none
        case .brightnessDown, .brightnessUp,
             .keyboardBrightnessDown, .keyboardBrightnessUp,
             .mediaPrevious, .mediaPlayPause, .mediaNext,
             .volumeMute, .volumeDown, .volumeUp:
            return .none
        }
    }
}

protocol PointerController {
    func applyMove(dx: CGFloat, dy: CGFloat)
    func applyButton(_ button: PointerButton, phase: ButtonPhase, clickCount: Int)
    func applyScroll(dx: CGFloat, dy: CGFloat, phase: SharedCore.ScrollPhase)
    func applyGestureCommand(_ kind: GestureKind, shortcut: ShortcutBinding)
}

final class CoreGraphicsPointerController: PointerController {
    private var pressedButtons: Set<PointerButton> = []
    private var cachedPointerLocation: CGPoint?
    private var scrollRemainder = CGPoint.zero
    private var scrollSamples: [(dx: CGFloat, dy: CGFloat)] = []
    private var momentumTimer: Timer?
    private var momentumVX: CGFloat = 0
    private var momentumVY: CGFloat = 0
    private var momentumRemainderX: CGFloat = 0
    private var momentumRemainderY: CGFloat = 0
    private var momentumPhaseIsFirst = true

    func applyMove(dx: CGFloat, dy: CGFloat) {
        let currentLocation = currentPointerLocation()
        let proposed = CGPoint(x: currentLocation.x + dx, y: currentLocation.y + dy)
        let destination = projectedPoint(for: proposed)
        CGWarpMouseCursorPosition(destination)
        cachedPointerLocation = destination

        let eventType: CGEventType
        if pressedButtons.contains(.left) {
            eventType = .leftMouseDragged
        } else if pressedButtons.contains(.right) {
            eventType = .rightMouseDragged
        } else {
            eventType = .mouseMoved
        }

        let moved = CGEvent(
            mouseEventSource: nil,
            mouseType: eventType,
            mouseCursorPosition: destination,
            mouseButton: pressedButtons.contains(.right) ? .right : .left
        )
        moved?.post(tap: .cghidEventTap)
    }

    func applyButton(_ button: PointerButton, phase: ButtonPhase, clickCount: Int) {
        let location = currentPointerLocation()

        let eventType: CGEventType
        switch (button, phase) {
        case (.left, .down):
            pressedButtons.insert(.left)
            eventType = .leftMouseDown
        case (.left, .up):
            eventType = .leftMouseUp
        case (.right, .down):
            pressedButtons.insert(.right)
            eventType = .rightMouseDown
        case (.right, .up):
            eventType = .rightMouseUp
        }

        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: eventType,
            mouseCursorPosition: location,
            mouseButton: button == .left ? .left : .right
        )
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(max(1, clickCount)))
        event?.post(tap: .cghidEventTap)

        if phase == .up {
            pressedButtons.remove(button)
        }
    }

    func applyScroll(dx: CGFloat, dy: CGFloat, phase: SharedCore.ScrollPhase) {
        if phase == .began {
            stopMomentum()
            scrollSamples.removeAll()
        }

        scrollRemainder.x += dx
        scrollRemainder.y += dy

        let wheelX = Int32(scrollRemainder.x.rounded(.towardZero))
        let wheelY = Int32(scrollRemainder.y.rounded(.towardZero))

        scrollRemainder.x -= CGFloat(wheelX)
        scrollRemainder.y -= CGFloat(wheelY)

        if phase == .changed {
            scrollSamples.append((dx: dx, dy: dy))
            if scrollSamples.count > 10 {
                scrollSamples.removeFirst()
            }
        }

        if phase == .ended {
            scrollRemainder = .zero
            let recent = scrollSamples.suffix(5)
            if !recent.isEmpty {
                let avgDX = recent.map(\.dx).reduce(0, +) / CGFloat(recent.count)
                let avgDY = recent.map(\.dy).reduce(0, +) / CGFloat(recent.count)
                if hypot(avgDX, avgDY) > 0.5 {
                    startMomentum(velocityX: avgDX, velocityY: avgDY)
                    scrollSamples.removeAll()
                    return
                }
            }
            scrollSamples.removeAll()
        }

        guard phase == .ended || wheelX != 0 || wheelY != 0 else {
            return
        }

        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: wheelY,
            wheel2: wheelX,
            wheel3: 0
        )
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event?.setIntegerValueField(.scrollWheelEventScrollPhase, value: scrollPhaseValue(for: phase))
        event?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        event?.post(tap: .cghidEventTap)
    }

    private func startMomentum(velocityX: CGFloat, velocityY: CGFloat) {
        scrollRemainder = .zero
        momentumVX = velocityX
        momentumVY = velocityY
        momentumRemainderX = 0
        momentumRemainderY = 0
        momentumPhaseIsFirst = true

        // Post the regular scroll ended event first so apps know the finger-driven phase ended.
        let endedEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        )
        endedEvent?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        endedEvent?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
        endedEvent?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        endedEvent?.post(tap: .cghidEventTap)

        momentumTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.momentumTick()
        }
        RunLoop.main.add(momentumTimer!, forMode: .common)
    }

    private func stopMomentum() {
        momentumTimer?.invalidate()
        momentumTimer = nil
        momentumVX = 0
        momentumVY = 0
    }

    private func momentumTick() {
        let decay: CGFloat = 0.93
        momentumVX *= decay
        momentumVY *= decay

        let speed = hypot(momentumVX, momentumVY)
        if speed < 0.3 {
            momentumTimer?.invalidate()
            momentumTimer = nil
            let endedEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: 0,
                wheel2: 0,
                wheel3: 0
            )
            endedEvent?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            endedEvent?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
            endedEvent?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 4)
            endedEvent?.post(tap: .cghidEventTap)
            return
        }

        momentumRemainderX += momentumVX
        momentumRemainderY += momentumVY
        let wheelX = Int32(momentumRemainderX.rounded(.towardZero))
        let wheelY = Int32(momentumRemainderY.rounded(.towardZero))
        momentumRemainderX -= CGFloat(wheelX)
        momentumRemainderY -= CGFloat(wheelY)

        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: wheelY,
            wheel2: wheelX,
            wheel3: 0
        )
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event?.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
        event?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumPhaseIsFirst ? 1 : 2)
        event?.post(tap: .cghidEventTap)
        momentumPhaseIsFirst = false
    }

    func applyGestureCommand(_ kind: GestureKind, shortcut: ShortcutBinding) {
        if let keyType = kind.mediaKeyType {
            postSystemKey(keyType, keyDown: true)
            postSystemKey(keyType, keyDown: false)
            return
        }
        guard let keyCode = shortcut.preset.keyCode else { return }
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        down?.flags = shortcut.preset.flags
        up?.flags = shortcut.preset.flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // Posts a system-defined media/hardware key event (NX_KEYTYPE_*).
    // data1 encodes both the key type and the key-down/key-up state as expected
    // by the CoreGraphics HID event tap (subtype 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS).
    // The flag bits follow the NX IOKit convention: 0x0a00 = key down, 0x0b00 = key up.
    private func postSystemKey(_ keyType: Int32, keyDown: Bool) {
        let flagBits: Int32 = keyDown ? 0x0a00 : 0x0b00  // key-down / key-up NX flag
        let data1 = Int((keyType << 16) | flagBits)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }

    private func scrollPhaseValue(for phase: SharedCore.ScrollPhase) -> Int64 {
        switch phase {
        case .began:
            return 1
        case .changed:
            return 2
        case .ended:
            return 4
        }
    }

    private func currentPointerLocation() -> CGPoint {
        if let cachedPointerLocation {
            return cachedPointerLocation
        }

        // NSEvent.mouseLocation is in AppKit global coordinates (y increases upward from the
        // bottom-left of the primary screen). CGWarpMouseCursorPosition and all CG APIs use
        // global display coordinates (y increases downward from the top-left of the primary
        // screen). Convert once so all subsequent math stays in CG space.
        let nsPoint = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cgPoint = CGPoint(x: nsPoint.x, y: primaryHeight - nsPoint.y)
        cachedPointerLocation = cgPoint
        return cgPoint
    }

    private func projectedPoint(for point: CGPoint) -> CGPoint {
        let screens = cgScreenFrames()
        guard !screens.isEmpty else { return point }

        if let containing = screens.first(where: { contains(point, in: $0) }) {
            return clamp(point, to: containing)
        }

        let nearest = screens.min { lhs, rhs in
            distanceSquared(from: point, to: clamp(point, to: lhs)) < distanceSquared(from: point, to: clamp(point, to: rhs))
        }

        guard let nearest else { return point }
        return clamp(point, to: nearest)
    }

    // NSScreen frames are in AppKit global coordinates (y-up). Convert them to CG global
    // coordinates (y-down) so they match the CGPoint values we work with internally.
    private func cgScreenFrames() -> [CGRect] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.map { screen in
            let f = screen.frame
            return CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)
        }
    }

    private func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX - 1),
            y: min(max(point.y, rect.minY), rect.maxY - 1)
        )
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return dx * dx + dy * dy
    }
}

extension GestureKind {
    var displayName: String {
        switch self {
        case .pageBack:
            return "前のページに戻る"
        case .pageForward:
            return "次のページに進む"
        case .missionControl:
            return "Mission Control"
        case .appExpose:
            return "App Exposé"
        case .launchpad:
            return "Launchpad"
        case .showDesktop:
            return "デスクトップを表示"
        case .spaceLeft:
            return "左のスペースへ移動"
        case .spaceRight:
            return "右のスペースへ移動"
        case .zoomIn:
            return "拡大"
        case .zoomOut:
            return "縮小"
        case .smartZoom:
            return "スマートズーム"
        case .rotateLeft:
            return "左に回転"
        case .rotateRight:
            return "右に回転"
        case .brightnessDown:
            return "明るさを下げる"
        case .brightnessUp:
            return "明るさを上げる"
        case .keyboardBrightnessDown:
            return "キーボードの明るさを下げる"
        case .keyboardBrightnessUp:
            return "キーボードの明るさを上げる"
        case .mediaPrevious:
            return "前のトラック"
        case .mediaPlayPause:
            return "再生 / 一時停止"
        case .mediaNext:
            return "次のトラック"
        case .volumeMute:
            return "消音"
        case .volumeDown:
            return "音量を下げる"
        case .volumeUp:
            return "音量を上げる"
        }
    }

    // NX_KEYTYPE_* values for media/hardware keys posted as systemDefined events.
    // Returns nil for gesture kinds that use keyboard shortcuts instead.
    var mediaKeyType: Int32? {
        switch self {
        case .brightnessDown:         return 3   // NX_KEYTYPE_BRIGHTNESS_DOWN
        case .brightnessUp:           return 2   // NX_KEYTYPE_BRIGHTNESS_UP
        case .keyboardBrightnessDown: return 22  // NX_KEYTYPE_ILLUMINATION_DOWN
        case .keyboardBrightnessUp:   return 21  // NX_KEYTYPE_ILLUMINATION_UP
        case .mediaPrevious:          return 20  // NX_KEYTYPE_PREVIOUS
        case .mediaPlayPause:         return 16  // NX_KEYTYPE_PLAY
        case .mediaNext:              return 17  // NX_KEYTYPE_NEXT
        case .volumeMute:             return 7   // NX_KEYTYPE_MUTE
        case .volumeDown:             return 1   // NX_KEYTYPE_SOUND_DOWN
        case .volumeUp:               return 0   // NX_KEYTYPE_SOUND_UP
        default:                      return nil
        }
    }
}
