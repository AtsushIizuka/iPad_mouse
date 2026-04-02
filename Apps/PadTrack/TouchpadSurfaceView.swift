import SharedCore
import SwiftUI
import UIKit

struct TouchpadSurfaceConfiguration: Equatable {
    var tapToClick: Bool
    var secondaryClickMode: SecondaryClickMode
    var swipeBetweenPages: Bool
    var zoomEnabled: Bool
    var smartZoomEnabled: Bool
    var rotateEnabled: Bool
    var missionControlEnabled: Bool
    var appExposeEnabled: Bool
    var swipeBetweenSpacesEnabled: Bool
    var launchpadEnabled: Bool
    var showDesktopEnabled: Bool
    var threeFingerDragEnabled: Bool

    init(
        tapToClick: Bool = true,
        secondaryClickMode: SecondaryClickMode = .twoFingerTap,
        swipeBetweenPages: Bool = true,
        zoomEnabled: Bool = true,
        smartZoomEnabled: Bool = true,
        rotateEnabled: Bool = true,
        missionControlEnabled: Bool = true,
        appExposeEnabled: Bool = true,
        swipeBetweenSpacesEnabled: Bool = true,
        launchpadEnabled: Bool = true,
        showDesktopEnabled: Bool = true,
        threeFingerDragEnabled: Bool = false
    ) {
        self.tapToClick = tapToClick
        self.secondaryClickMode = secondaryClickMode
        self.swipeBetweenPages = swipeBetweenPages
        self.zoomEnabled = zoomEnabled
        self.smartZoomEnabled = smartZoomEnabled
        self.rotateEnabled = rotateEnabled
        self.missionControlEnabled = missionControlEnabled
        self.appExposeEnabled = appExposeEnabled
        self.swipeBetweenSpacesEnabled = swipeBetweenSpacesEnabled
        self.launchpadEnabled = launchpadEnabled
        self.showDesktopEnabled = showDesktopEnabled
        self.threeFingerDragEnabled = threeFingerDragEnabled
    }

    @MainActor init(preferences: TrackpadPreferences) {
        tapToClick = preferences.tapToClick
        secondaryClickMode = preferences.secondaryClickMode
        swipeBetweenPages = preferences.swipeBetweenPages
        zoomEnabled = preferences.zoomEnabled
        smartZoomEnabled = preferences.smartZoomEnabled
        rotateEnabled = preferences.rotateEnabled
        missionControlEnabled = preferences.missionControlEnabled
        appExposeEnabled = preferences.appExposeEnabled
        swipeBetweenSpacesEnabled = preferences.swipeBetweenSpacesEnabled
        launchpadEnabled = preferences.launchpadEnabled
        showDesktopEnabled = preferences.showDesktopEnabled
        threeFingerDragEnabled = preferences.threeFingerDragEnabled
    }
}

struct TouchpadSurfaceView: UIViewRepresentable {
    let configuration: TouchpadSurfaceConfiguration
    let onPointerMove: (CGPoint) -> Void
    let onButton: (PointerButton, ButtonPhase, Int) -> Void
    let onPrimaryDoubleClick: () -> Void
    let onScroll: (CGPoint, SharedCore.ScrollPhase) -> Void
    let onGesture: (GestureKind) -> Void
    let onNewTouchSequence: () -> Void

    func makeUIView(context: Context) -> TouchpadUIView {
        let view = TouchpadUIView()
        view.configuration = configuration
        view.onPointerMove = onPointerMove
        view.onButton = onButton
        view.onPrimaryDoubleClick = onPrimaryDoubleClick
        view.onScroll = onScroll
        view.onGesture = onGesture
        view.onNewTouchSequence = onNewTouchSequence
        return view
    }

    func updateUIView(_ uiView: TouchpadUIView, context: Context) {
        uiView.configuration = configuration
        uiView.onPointerMove = onPointerMove
        uiView.onButton = onButton
        uiView.onPrimaryDoubleClick = onPrimaryDoubleClick
        uiView.onScroll = onScroll
        uiView.onGesture = onGesture
        uiView.onNewTouchSequence = onNewTouchSequence
    }
}

final class TouchpadUIView: UIView {
    struct TouchSample {
        let startPoint: CGPoint
        let startTime: TimeInterval
        var previousPoint: CGPoint
        var currentPoint: CGPoint
    }

    private enum TwoFingerMode {
        case undecided
        case scrolling
        case pageSwipe
        case pinching
        case rotating
    }

    var configuration = TouchpadSurfaceConfiguration()
    var onPointerMove: ((CGPoint) -> Void)?
    var onButton: ((PointerButton, ButtonPhase, Int) -> Void)?
    var onPrimaryDoubleClick: (() -> Void)?
    var onScroll: ((CGPoint, SharedCore.ScrollPhase) -> Void)?
    var onGesture: ((GestureKind) -> Void)?
    var onNewTouchSequence: (() -> Void)?

    private var trackedTouches: [ObjectIdentifier: TouchSample] = [:]

    private var pendingPrimaryTap: DispatchWorkItem?
    private var pendingPrimaryLongPress: DispatchWorkItem?
    private var lastPrimaryTapTimestamp: TimeInterval?
    private var secondPrimaryTapActive = false
    private var primaryDragActive = false

    private var pendingSecondaryTap: DispatchWorkItem?
    private var lastTwoFingerTapTimestamp: TimeInterval?

    private var twoFingerMode: TwoFingerMode = .undecided
    private var twoFingerTranslation = CGPoint.zero
    private var twoFingerStartDistance: CGFloat = 0
    private var twoFingerStartAngle: CGFloat = 0
    private var scrollHasBegun = false

    private var multiFingerTranslation = CGPoint.zero
    private var multiFingerStartRadius: CGFloat = 0
    private var threeFingerDragActive = false
    private var threeFingerGestureTriggered = false
    private var fourFingerGestureTriggered = false

    private let tapMovementThreshold: CGFloat = 12
    private let tapDurationThreshold: TimeInterval = 0.25
    private let doubleTapWindow: TimeInterval = 0.28
    private let longPressDragDelay: TimeInterval = 0.22
    private let dragTriggerDistance: CGFloat = 10
    private let scrollTriggerDistance: CGFloat = 12
    private let pageSwipeDistance: CGFloat = 90
    private let pinchLogThreshold: CGFloat = 0.15
    private let rotationThreshold: CGFloat = 0.34
    private let threeFingerSwipeDistance: CGFloat = 92
    private let fourFingerSwipeDistance: CGFloat = 110
    private let pinchInThreshold: CGFloat = 0.82
    private let pinchOutThreshold: CGFloat = 1.18

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if trackedTouches.isEmpty {
            resetSequenceState()
            onNewTouchSequence?()
        }

        for touch in touches {
            let point = touch.location(in: self)
            trackedTouches[ObjectIdentifier(touch)] = TouchSample(
                startPoint: point,
                startTime: touch.timestamp,
                previousPoint: point,
                currentPoint: point
            )
        }

        switch trackedTouches.count {
        case 1:
            handleSingleTouchBegan()
        case 2:
            cancelPendingPrimaryTap()
            prepareTwoFingerSequence()
        case 3:
            cancelPendingTapActions()
            prepareMultiFingerSequence()
        case 4:
            cancelPendingTapActions()
            prepareMultiFingerSequence()
        default:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if processCoalescedSingleTouchMove(touches, event: event) {
            return
        }

        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard var sample = trackedTouches[key] else { continue }
            sample.previousPoint = sample.currentPoint
            sample.currentPoint = touch.location(in: self)
            trackedTouches[key] = sample
        }

        let samples = currentSamples()
        switch samples.count {
        case 1:
            handleSingleTouchMoved(samples[0])
        case 2:
            handleTwoFingerMoved(samples)
        case 3:
            handleThreeFingerMoved(samples)
        case 4:
            handleFourFingerMoved(samples)
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let samples = currentSamples()
        let endingCount = samples.count
        let endTimestamp = touches.map(\.timestamp).max() ?? 0
        let isSequenceEnding = endingCount == touches.count

        switch endingCount {
        case 1:
            handleSingleTouchEnded(samples: samples, endTimestamp: endTimestamp, isSequenceEnding: isSequenceEnding)
        case 2:
            handleTwoFingerEnded(samples: samples, endTimestamp: endTimestamp, isSequenceEnding: isSequenceEnding)
        case 3:
            handleThreeFingerEnded()
        case 4:
            handleFourFingerEnded()
        default:
            break
        }

        removeTouches(touches)
        if trackedTouches.isEmpty {
            resetSequenceState()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelPendingPrimaryLongPress()
        if primaryDragActive {
            onButton?(.left, .up, 1)
        }
        if threeFingerDragActive {
            onButton?(.left, .up, 1)
        }
        if scrollHasBegun {
            onScroll?(.zero, .ended)
        }
        removeTouches(touches)
        resetSequenceState()
    }

    private func handleSingleTouchBegan() {
        guard
            configuration.tapToClick,
            let sample = currentSamples().first,
            let lastPrimaryTapTimestamp,
            sample.startTime - lastPrimaryTapTimestamp <= doubleTapWindow
        else {
            secondPrimaryTapActive = false
            schedulePrimaryLongPress()
            return
        }

        cancelPendingPrimaryTap()
        cancelPendingPrimaryLongPress()
        secondPrimaryTapActive = true
    }

    private func handleSingleTouchMoved(_ sample: TouchSample) {
        let delta = CGPoint(
            x: sample.currentPoint.x - sample.previousPoint.x,
            y: sample.currentPoint.y - sample.previousPoint.y
        )

        if !primaryDragActive, distance(from: sample.startPoint, to: sample.currentPoint) > tapMovementThreshold {
            cancelPendingPrimaryLongPress()
        }

        if secondPrimaryTapActive {
            let translation = distance(from: sample.startPoint, to: sample.currentPoint)
            if !primaryDragActive, translation > dragTriggerDistance {
                primaryDragActive = true
                onButton?(.left, .down, 1)
            }

            if primaryDragActive {
                onPointerMove?(delta)
            }
            return
        }

        onPointerMove?(delta)
    }

    private func handleSingleTouchEnded(samples: [TouchSample], endTimestamp: TimeInterval, isSequenceEnding: Bool) {
        guard let sample = samples.first else { return }
        cancelPendingPrimaryLongPress()

        if primaryDragActive {
            onButton?(.left, .up, 1)
            primaryDragActive = false
            secondPrimaryTapActive = false
            return
        }

        guard isSequenceEnding else { return }

        if secondPrimaryTapActive {
            secondPrimaryTapActive = false
            if configuration.tapToClick, isTap(sample: sample, endTimestamp: endTimestamp) {
                lastPrimaryTapTimestamp = nil
                onPrimaryDoubleClick?()
            }
            return
        }

        guard configuration.tapToClick, isTap(sample: sample, endTimestamp: endTimestamp) else { return }
        schedulePrimaryTap(at: endTimestamp)
    }

    private func handleTwoFingerMoved(_ samples: [TouchSample]) {
        let averageDelta = CGPoint(
            x: samples.map { $0.currentPoint.x - $0.previousPoint.x }.reduce(0, +) / 2,
            y: samples.map { $0.currentPoint.y - $0.previousPoint.y }.reduce(0, +) / 2
        )
        twoFingerTranslation.x += averageDelta.x
        twoFingerTranslation.y += averageDelta.y

        if twoFingerMode == .undecided {
            let currentVector = vector(between: samples[0].currentPoint, and: samples[1].currentPoint)
            let currentDistance = hypot(currentVector.x, currentVector.y)
            let scaleRatio = twoFingerStartDistance == 0 ? 1 : currentDistance / twoFingerStartDistance
            let scaleDelta = abs(log(max(scaleRatio, 0.001)))
            let rotationDelta = normalizedAngle(atan2(currentVector.y, currentVector.x) - twoFingerStartAngle)

            if configuration.zoomEnabled, scaleDelta > pinchLogThreshold {
                twoFingerMode = .pinching
                onGesture?(scaleRatio > 1 ? .zoomIn : .zoomOut)
                return
            }

            if configuration.rotateEnabled, abs(rotationDelta) > rotationThreshold {
                twoFingerMode = .rotating
                onGesture?(rotationDelta > 0 ? .rotateRight : .rotateLeft)
                return
            }

            if configuration.swipeBetweenPages,
               abs(twoFingerTranslation.x) > pageSwipeDistance,
               abs(twoFingerTranslation.x) > abs(twoFingerTranslation.y) * 1.4 {
                twoFingerMode = .pageSwipe
                onGesture?(twoFingerTranslation.x > 0 ? .pageForward : .pageBack)
                return
            }

            if abs(twoFingerTranslation.x) > scrollTriggerDistance || abs(twoFingerTranslation.y) > scrollTriggerDistance {
                twoFingerMode = .scrolling
            }
        }

        guard twoFingerMode == .scrolling else { return }
        onScroll?(averageDelta, scrollHasBegun ? .changed : .began)
        scrollHasBegun = true
    }

    private func handleTwoFingerEnded(samples: [TouchSample], endTimestamp: TimeInterval, isSequenceEnding: Bool) {
        if scrollHasBegun {
            onScroll?(.zero, .ended)
        }

        defer {
            twoFingerMode = .undecided
            twoFingerTranslation = .zero
            scrollHasBegun = false
        }

        guard isSequenceEnding, twoFingerMode == .undecided, areTaps(samples: samples, endTimestamp: endTimestamp) else {
            return
        }

        handleTwoFingerTap(at: endTimestamp, centroid: centroid(of: samples))
    }

    private func handleThreeFingerMoved(_ samples: [TouchSample]) {
        let averageDelta = CGPoint(
            x: samples.map { $0.currentPoint.x - $0.previousPoint.x }.reduce(0, +) / 3,
            y: samples.map { $0.currentPoint.y - $0.previousPoint.y }.reduce(0, +) / 3
        )
        multiFingerTranslation.x += averageDelta.x
        multiFingerTranslation.y += averageDelta.y

        if configuration.threeFingerDragEnabled {
            let movement = hypot(multiFingerTranslation.x, multiFingerTranslation.y)
            if !threeFingerDragActive, movement > dragTriggerDistance {
                threeFingerDragActive = true
                onButton?(.left, .down, 1)
            }

            if threeFingerDragActive {
                onPointerMove?(averageDelta)
            }
            return
        }

        guard !threeFingerGestureTriggered else { return }

        if configuration.missionControlEnabled,
           multiFingerTranslation.y < -threeFingerSwipeDistance,
           abs(multiFingerTranslation.y) > abs(multiFingerTranslation.x) * 1.2 {
            threeFingerGestureTriggered = true
            onGesture?(.missionControl)
        } else if configuration.appExposeEnabled,
                  multiFingerTranslation.y > threeFingerSwipeDistance,
                  abs(multiFingerTranslation.y) > abs(multiFingerTranslation.x) * 1.2 {
            threeFingerGestureTriggered = true
            onGesture?(.appExpose)
        }
    }

    private func handleThreeFingerEnded() {
        if threeFingerDragActive {
            onButton?(.left, .up, 1)
        }
        threeFingerDragActive = false
        threeFingerGestureTriggered = false
        multiFingerTranslation = .zero
    }

    private func handleFourFingerMoved(_ samples: [TouchSample]) {
        let averageDelta = CGPoint(
            x: samples.map { $0.currentPoint.x - $0.previousPoint.x }.reduce(0, +) / 4,
            y: samples.map { $0.currentPoint.y - $0.previousPoint.y }.reduce(0, +) / 4
        )
        multiFingerTranslation.x += averageDelta.x
        multiFingerTranslation.y += averageDelta.y

        guard !fourFingerGestureTriggered else { return }

        let currentRadius = averageRadius(of: samples)
        let radiusRatio = multiFingerStartRadius == 0 ? 1 : currentRadius / multiFingerStartRadius

        if configuration.launchpadEnabled, radiusRatio < pinchInThreshold {
            fourFingerGestureTriggered = true
            onGesture?(.launchpad)
        } else if configuration.showDesktopEnabled, radiusRatio > pinchOutThreshold {
            fourFingerGestureTriggered = true
            onGesture?(.showDesktop)
        } else if configuration.swipeBetweenSpacesEnabled,
                  abs(multiFingerTranslation.x) > fourFingerSwipeDistance,
                  abs(multiFingerTranslation.x) > abs(multiFingerTranslation.y) * 1.25 {
            fourFingerGestureTriggered = true
            onGesture?(multiFingerTranslation.x > 0 ? .spaceLeft : .spaceRight)
        }
    }

    private func handleFourFingerEnded() {
        fourFingerGestureTriggered = false
        multiFingerTranslation = .zero
    }

    private func handleTwoFingerTap(at timestamp: TimeInterval, centroid: CGPoint) {
        let isSecondaryClickEligible = secondaryTapEligible(at: centroid)

        guard isSecondaryClickEligible || configuration.smartZoomEnabled else {
            lastTwoFingerTapTimestamp = nil
            return
        }

        if configuration.smartZoomEnabled,
           let lastTwoFingerTapTimestamp,
           timestamp - lastTwoFingerTapTimestamp <= doubleTapWindow {
            cancelPendingSecondaryTap()
            self.lastTwoFingerTapTimestamp = nil
            onGesture?(.smartZoom)
            return
        }

        self.lastTwoFingerTapTimestamp = timestamp
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if isSecondaryClickEligible {
                self.onButton?(.right, .down, 1)
                self.onButton?(.right, .up, 1)
            }
            self.pendingSecondaryTap = nil
            self.lastTwoFingerTapTimestamp = nil
        }
        pendingSecondaryTap?.cancel()
        pendingSecondaryTap = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapWindow, execute: workItem)
    }

    private func secondaryTapEligible(at centroid: CGPoint) -> Bool {
        switch configuration.secondaryClickMode {
        case .twoFingerTap:
            return true
        case .bottomRightTap:
            return centroid.x > bounds.width * 0.66 && centroid.y > bounds.height * 0.58
        case .bottomLeftTap:
            return centroid.x < bounds.width * 0.34 && centroid.y > bounds.height * 0.58
        case .off:
            return false
        }
    }

    private func prepareTwoFingerSequence() {
        let samples = currentSamples()
        guard samples.count == 2 else { return }
        twoFingerMode = .undecided
        twoFingerTranslation = .zero
        scrollHasBegun = false
        let currentVector = vector(between: samples[0].currentPoint, and: samples[1].currentPoint)
        twoFingerStartDistance = hypot(currentVector.x, currentVector.y)
        twoFingerStartAngle = atan2(currentVector.y, currentVector.x)
    }

    private func prepareMultiFingerSequence() {
        let samples = currentSamples()
        multiFingerTranslation = .zero
        multiFingerStartRadius = averageRadius(of: samples)
        threeFingerGestureTriggered = false
        fourFingerGestureTriggered = false
        threeFingerDragActive = false
    }

    private func schedulePrimaryTap(at timestamp: TimeInterval) {
        lastPrimaryTapTimestamp = timestamp
        let workItem = DispatchWorkItem { [weak self] in
            self?.onButton?(.left, .down, 1)
            self?.onButton?(.left, .up, 1)
            self?.pendingPrimaryTap = nil
            self?.lastPrimaryTapTimestamp = nil
        }
        pendingPrimaryTap?.cancel()
        pendingPrimaryTap = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapWindow, execute: workItem)
    }

    private func schedulePrimaryLongPress() {
        let workItem = DispatchWorkItem { [weak self] in
            guard
                let self,
                self.trackedTouches.count == 1,
                let sample = self.currentSamples().first,
                self.distance(from: sample.startPoint, to: sample.currentPoint) <= self.tapMovementThreshold,
                !self.primaryDragActive
            else {
                self?.pendingPrimaryLongPress = nil
                return
            }

            self.primaryDragActive = true
            self.secondPrimaryTapActive = false
            self.pendingPrimaryLongPress = nil
            self.onButton?(.left, .down, 1)
        }

        cancelPendingPrimaryLongPress()
        pendingPrimaryLongPress = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDragDelay, execute: workItem)
    }

    private func cancelPendingPrimaryTap() {
        pendingPrimaryTap?.cancel()
        pendingPrimaryTap = nil
    }

    private func cancelPendingPrimaryLongPress() {
        pendingPrimaryLongPress?.cancel()
        pendingPrimaryLongPress = nil
    }

    private func cancelPendingSecondaryTap() {
        pendingSecondaryTap?.cancel()
        pendingSecondaryTap = nil
    }

    private func cancelPendingTapActions() {
        cancelPendingPrimaryTap()
        cancelPendingPrimaryLongPress()
        cancelPendingSecondaryTap()
        lastPrimaryTapTimestamp = nil
        lastTwoFingerTapTimestamp = nil
    }

    private func resetSequenceState() {
        cancelPendingPrimaryLongPress()
        secondPrimaryTapActive = false
        primaryDragActive = false
        threeFingerDragActive = false
        twoFingerMode = .undecided
        twoFingerTranslation = .zero
        twoFingerStartDistance = 0
        twoFingerStartAngle = 0
        scrollHasBegun = false
        multiFingerTranslation = .zero
        multiFingerStartRadius = 0
        threeFingerGestureTriggered = false
        fourFingerGestureTriggered = false
    }

    private func processCoalescedSingleTouchMove(_ touches: Set<UITouch>, event: UIEvent?) -> Bool {
        guard
            trackedTouches.count == 1,
            touches.count == 1,
            let touch = touches.first,
            let coalescedTouches = event?.coalescedTouches(for: touch),
            !coalescedTouches.isEmpty
        else {
            return false
        }

        let key = ObjectIdentifier(touch)
        guard var sample = trackedTouches[key] else { return false }

        for coalescedTouch in coalescedTouches {
            sample.previousPoint = sample.currentPoint
            sample.currentPoint = coalescedTouch.location(in: self)
            trackedTouches[key] = sample
            handleSingleTouchMoved(sample)
        }

        return true
    }

    private func removeTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            trackedTouches.removeValue(forKey: ObjectIdentifier(touch))
        }
    }

    private func currentSamples() -> [TouchSample] {
        trackedTouches.values.sorted {
            if $0.startPoint.x == $1.startPoint.x {
                return $0.startPoint.y < $1.startPoint.y
            }
            return $0.startPoint.x < $1.startPoint.x
        }
    }

    private func areTaps(samples: [TouchSample], endTimestamp: TimeInterval) -> Bool {
        samples.allSatisfy { isTap(sample: $0, endTimestamp: endTimestamp) }
    }

    private func isTap(sample: TouchSample, endTimestamp: TimeInterval) -> Bool {
        let duration = endTimestamp - sample.startTime
        let distance = distance(from: sample.startPoint, to: sample.currentPoint)
        return duration < tapDurationThreshold && distance < tapMovementThreshold
    }

    private func centroid(of samples: [TouchSample]) -> CGPoint {
        guard !samples.isEmpty else { return .zero }
        let sum = samples.reduce(CGPoint.zero) { partial, sample in
            CGPoint(x: partial.x + sample.currentPoint.x, y: partial.y + sample.currentPoint.y)
        }
        return CGPoint(x: sum.x / CGFloat(samples.count), y: sum.y / CGFloat(samples.count))
    }

    private func averageRadius(of samples: [TouchSample]) -> CGFloat {
        guard !samples.isEmpty else { return 0 }
        let center = centroid(of: samples)
        let total = samples.reduce(CGFloat.zero) { partial, sample in
            partial + distance(from: center, to: sample.currentPoint)
        }
        return total / CGFloat(samples.count)
    }

    private func vector(between lhs: CGPoint, and rhs: CGPoint) -> CGPoint {
        CGPoint(x: rhs.x - lhs.x, y: rhs.y - lhs.y)
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(rhs.x - lhs.x, rhs.y - lhs.y)
    }

    private func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var value = angle
        while value > .pi {
            value -= 2 * .pi
        }
        while value < -.pi {
            value += 2 * .pi
        }
        return value
    }
}
