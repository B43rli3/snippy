import AppKit

final class OverlayWindow: NSWindow {
    var onRegionSelected: ((NSRect) -> Void)?
    var onWindowChosen: ((CGWindowID) -> Void)?
    var onCancel: (() -> Void)?

    convenience init(display: FrozenDisplay, state: OverlayState, windows: [CapturableWindow]) {
        self.init(
            contentRect: NSRect(origin: .zero, size: display.screen.frame.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(display.screen.frame, display: true)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        sharingType = .none
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        title = "Snippy Overlay"
        identifier = NSUserInterfaceItemIdentifier("snippy.overlay")

        let view = OverlayContentView(display: display, state: state, windows: windows)
        view.onRegionSelected = { [weak self] rect in
            self?.onRegionSelected?(rect)
        }
        view.onWindowChosen = { [weak self] windowID in
            self?.onWindowChosen?(windowID)
        }
        view.onCancel = { [weak self] in
            self?.onCancel?()
        }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
