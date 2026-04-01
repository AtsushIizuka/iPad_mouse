import Foundation

public enum PointerButton: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case left
    case right
}

public enum ButtonPhase: String, Codable, Sendable, Equatable, Hashable {
    case down
    case up
}

public enum ScrollPhase: String, Codable, Sendable, Equatable, Hashable {
    case began
    case changed
    case ended
}

public enum GestureKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case pageBack
    case pageForward
    case missionControl
    case appExpose
    case launchpad
    case showDesktop
    case spaceLeft
    case spaceRight
    case zoomIn
    case zoomOut
    case smartZoom
    case rotateLeft
    case rotateRight
}

public enum InputEvent: Sendable, Equatable {
    case pointerMove(dx: Float, dy: Float, ts: UInt64)
    case click(button: PointerButton, clickCount: Int, ts: UInt64)
    case button(button: PointerButton, phase: ButtonPhase, clickCount: Int, ts: UInt64)
    case scroll(dx: Float, dy: Float, phase: ScrollPhase, ts: UInt64)
    case gesture(kind: GestureKind, ts: UInt64)
}

extension InputEvent: Codable {
    private enum LegacyClickKind: String, Codable {
        case left
        case doubleLeft
    }

    private enum LegacyNavigationKind: String, Codable {
        case back
        case forward
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case dx
        case dy
        case ts
        case button
        case phase
        case clickCount
        case gesture
    }

    private enum EventType: String, Codable {
        case pointerMove
        case click
        case button
        case scroll
        case gesture
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)

        switch rawType {
        case EventType.pointerMove.rawValue, "move":
            self = .pointerMove(
                dx: try container.decode(Float.self, forKey: .dx),
                dy: try container.decode(Float.self, forKey: .dy),
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        case EventType.click.rawValue:
            self = .click(
                button: try container.decode(PointerButton.self, forKey: .button),
                clickCount: try container.decode(Int.self, forKey: .clickCount),
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        case EventType.button.rawValue:
            self = .button(
                button: try container.decode(PointerButton.self, forKey: .button),
                phase: try container.decode(ButtonPhase.self, forKey: .phase),
                clickCount: try container.decode(Int.self, forKey: .clickCount),
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        case "click":
            let click = try container.decode(LegacyClickKind.self, forKey: .button)
            self = .click(
                button: .left,
                clickCount: click == .doubleLeft ? 2 : 1,
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        case EventType.scroll.rawValue:
            self = .scroll(
                dx: try container.decode(Float.self, forKey: .dx),
                dy: try container.decode(Float.self, forKey: .dy),
                phase: try container.decodeIfPresent(ScrollPhase.self, forKey: .phase) ?? .changed,
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        case EventType.gesture.rawValue:
            self = .gesture(
                kind: try container.decode(GestureKind.self, forKey: .gesture),
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        case "navigation":
            let navigation = try container.decode(LegacyNavigationKind.self, forKey: .gesture)
            self = .gesture(
                kind: navigation == .back ? .pageBack : .pageForward,
                ts: try container.decodeIfPresent(UInt64.self, forKey: .ts) ?? 0
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported input event type: \(rawType)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .pointerMove(dx, dy, ts):
            try container.encode(EventType.pointerMove, forKey: .type)
            try container.encode(dx, forKey: .dx)
            try container.encode(dy, forKey: .dy)
            try container.encode(ts, forKey: .ts)
        case let .click(button, clickCount, ts):
            try container.encode(EventType.click, forKey: .type)
            try container.encode(button, forKey: .button)
            try container.encode(clickCount, forKey: .clickCount)
            try container.encode(ts, forKey: .ts)
        case let .button(button, phase, clickCount, ts):
            try container.encode(EventType.button, forKey: .type)
            try container.encode(button, forKey: .button)
            try container.encode(phase, forKey: .phase)
            try container.encode(clickCount, forKey: .clickCount)
            try container.encode(ts, forKey: .ts)
        case let .scroll(dx, dy, phase, ts):
            try container.encode(EventType.scroll, forKey: .type)
            try container.encode(dx, forKey: .dx)
            try container.encode(dy, forKey: .dy)
            try container.encode(phase, forKey: .phase)
            try container.encode(ts, forKey: .ts)
        case let .gesture(kind, ts):
            try container.encode(EventType.gesture, forKey: .type)
            try container.encode(kind, forKey: .gesture)
            try container.encode(ts, forKey: .ts)
        }
    }
}
