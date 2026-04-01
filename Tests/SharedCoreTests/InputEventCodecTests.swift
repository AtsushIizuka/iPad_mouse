import Foundation
import Testing
@testable import SharedCore

struct InputEventCodecTests {
    @Test func pointerMoveEventRoundTripsThroughJSON() throws {
        let original = InputEvent.pointerMove(dx: 12.5, dy: -3.25, ts: 42)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

        #expect(decoded == original)
    }

    @Test func buttonEventRoundTripsThroughJSON() throws {
        let original = InputEvent.button(button: .right, phase: .down, clickCount: 2, ts: 18)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

        #expect(decoded == original)
    }

    @Test func scrollEventRoundTripsThroughJSON() throws {
        let original = InputEvent.scroll(dx: -8.5, dy: 19.0, phase: .changed, ts: 99)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

        #expect(decoded == original)
    }

    @Test func gestureEventRoundTripsThroughJSON() throws {
        let original = InputEvent.gesture(kind: .missionControl, ts: 101)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

        #expect(decoded == original)
    }

    @Test func serviceTypeFitsBonjourLimit() {
        #expect(PeerTransportClient.serviceType.count <= 15)
    }
}
