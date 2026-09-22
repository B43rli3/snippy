import AppKit
import Combine

final class OverlayContentView: NSView {
    var onRegionSelected: ((NSRect) -> Void)?
    var onWindowChosen: ((CGWindowID) -> Void)?
    var onCancel: (() -> Void)?

    private let display: FrozenDisplay
    private let state: OverlayState
    private let windows: [CapturableWindow]
    private let snapshot: NSImage
    private var cancellables: Set<AnyCancellable> = []

    private var dragOrigin: NSPoint?
    private var dragRect: NSRect?
    private var highlightedWindow: CapturableWindow?

    init(display: FrozenDisplay, state: OverlayState, windows: [CapturableWindow]) {
        self.display = display
        self.state = state
        self.windows = windows
        self.snapshot = NSImage(cgImage: display.image, size: display.screen.frame.size)
        super.init(frame: NSRect(origin: .zero, size: display.screen.frame.size))
        wantsLayer = true

        state.$mode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.dragOrigin = nil
                self.dragRect = nil
                self.syncWindowHighlight()
                self.needsDisplay = true
                self.window?.invalidateCursorRects(for: self)
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTrackingAreas()
        syncWindowHighlight()
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func resetCursorRects() {
        discardCursorRects()
        switch state.mode {
        case .region:
            addCursorRect(bounds, cursor: .crosshair)
        case .window:
            addCursorRect(bounds, cursor: .pointingHand)
        case .screen:
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        switch state.mode {
        case .region:
            NSCursor.crosshair.set()
        case .window:
            NSCursor.pointingHand.set()
        case .screen:
            NSCursor.arrow.set()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        snapshot.draw(in: bounds)

        let hole: NSRect? = {
            switch state.mode {
            case .region:
                return dragRect
            case .window:
                return highlightedFrame()
            case .screen:
                return nil
            }
        }()

        NSColor.black.withAlphaComponent(0.4).setFill()
        if let hole, hole.width > 1, hole.height > 1 {
            let path = NSBezierPath(rect: bounds)
            path.append(NSBezierPath(rect: hole.integral))
            path.windingRule = .evenOdd
            path.fill()

            NSColor.white.setStroke()
            let border = NSBezierPath(rect: hole.integral)
            border.lineWidth = 2
            border.stroke()
        } else {
            bounds.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        switch state.mode {
        case .region:
            dragOrigin = point
            dragRect = NSRect(origin: point, size: .zero)
            needsDisplay = true
        case .window:
            if let target = windowAt(point) {
                onWindowChosen?(target.windowID)
            }
        case .screen:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard state.mode == .region, let origin = dragOrigin else { return }
        let point = convert(event.locationInWindow, from: nil)
        dragRect = normalizedRect(from: origin, to: point).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard state.mode == .region else { return }
        defer {
            dragOrigin = nil
        }
        guard let rect = dragRect, rect.width >= 8, rect.height >= 8 else {
            dragRect = nil
            needsDisplay = true
            return
        }
        onRegionSelected?(rect)
    }

    override func mouseMoved(with event: NSEvent) {
        guard state.mode == .window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let next = windowAt(point)
        if next?.windowID != highlightedWindow?.windowID {
            highlightedWindow = next
            needsDisplay = true
        }
    }

    override func mouseEntered(with event: NSEvent) {
        syncWindowHighlight()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    private func normalizedRect(from a: NSPoint, to b: NSPoint) -> NSRect {
        NSRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    private func highlightedFrame() -> NSRect? {
        guard let highlightedWindow, let window else { return nil }
        return convert(window.convertFromScreen(highlightedWindow.frameCocoa), from: nil)
    }

    private func windowAt(_ pointInView: NSPoint) -> CapturableWindow? {
        guard let window else { return nil }
        let globalPoint = window.convertToScreen(NSRect(origin: convert(pointInView, to: nil), size: .zero)).origin
        return windows.first { NSMouseInRect(globalPoint, $0.frameCocoa, false) }
    }

    private func syncWindowHighlight() {
        guard state.mode == .window, let window else {
            highlightedWindow = nil
            return
        }
        let global = NSEvent.mouseLocation
        let pointInWindow = window.convertFromScreen(NSRect(origin: global, size: .zero)).origin
        let pointInView = convert(pointInWindow, from: nil)
        highlightedWindow = windowAt(pointInView)
    }
}
