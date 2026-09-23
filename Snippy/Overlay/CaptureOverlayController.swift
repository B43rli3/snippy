import AppKit
import SwiftUI

/// Ein Overlay pro Bildschirm plus die Leiste oben. Escape und das X brechen ab.
final class CaptureOverlayController: NSObject, @unchecked Sendable {
    private(set) var isActive = false
    var onOutcome: ((OverlayOutcome) -> Void)?

    private let state = OverlayState()
    private var overlayWindows: [OverlayWindow] = []
    private var toolbarWindow: NSWindow?
    private var session: FrozenSession?
    private var windowCaptureGeneration = 0

    func present(_ session: FrozenSession) {
        cancel(notify: false)
        self.session = session
        isActive = true

        for display in session.displays {
            let window = OverlayWindow(display: display, state: state, windows: session.windows)
            window.onRegionSelected = { [weak self] rect in
                self?.finishRegion(rect, on: display)
            }
            window.onWindowChosen = { [weak self] windowID in
                self?.finishWindow(windowID)
            }
            window.onCancel = { [weak self] in
                self?.cancel(notify: true)
            }
            overlayWindows.append(window)
            window.orderFrontRegardless()
        }

        let mouseScreen = ScreenGeometry.screen(containing: NSEvent.mouseLocation)
        showToolbar(on: mouseScreen ?? session.displays.first?.screen)
        NSApp.activate(ignoringOtherApps: true)
        let keyWindow =
            overlayWindows.first { window in
                guard let mouseScreen else { return false }
                return window.frame.intersects(mouseScreen.frame)
            } ?? overlayWindows.first
        keyWindow?.makeKeyAndOrderFront(nil)
        // Die Leiste nach dem Overlay nach vorn, sonst schluckt die Fläche die Klicks auf Bildschirm und Fenster.
        toolbarWindow?.orderFrontRegardless()
    }

    func cancel(notify: Bool) {
        windowCaptureGeneration += 1
        let wasActive = isActive
        dismiss()
        if notify, wasActive {
            onOutcome?(.cancel)
        }
    }

    func captureTestRegion(_ rect: NSRect) {
        guard let display = session?.displays.first else { return }
        finishRegion(rect, on: display)
    }

    func captureActiveScreenForTest() {
        captureFullScreen(of: ScreenGeometry.screen(containing: NSEvent.mouseLocation))
    }

    private func finishRegion(_ rect: NSRect, on display: FrozenDisplay) {
        emitCroppedImage(rect, on: display)
    }

    /// Fenster einzeln aufnehmen. Die Generationsnummer verwirft das Ergebnis, wenn der Nutzer vorher abbricht.
    private func finishWindow(_ windowID: CGWindowID) {
        guard session?.windows.contains(where: { $0.windowID == windowID }) == true else {
            cancel(notify: true)
            return
        }
        windowCaptureGeneration += 1
        let generation = windowCaptureGeneration
        Task { @MainActor in
            do {
                let image = try await ScreenCaptureService.captureWindow(windowID: windowID)
                guard generation == self.windowCaptureGeneration, self.isActive else { return }
                self.dismiss()
                self.onOutcome?(.image(image))
            } catch {
                guard generation == self.windowCaptureGeneration, self.isActive else { return }
                self.dismiss()
                self.onOutcome?(.failed(error as? CaptureError ?? .captureFailed))
            }
        }
    }

    private func emitCroppedImage(_ rect: NSRect, on display: FrozenDisplay) {
        let imageBounds = CGRect(x: 0, y: 0, width: display.image.width, height: display.image.height)
        let crop = ScreenGeometry.crop(rect, viewSize: display.screen.frame.size, image: display.image).intersection(imageBounds)
        guard crop.width >= 1, crop.height >= 1, let image = display.image.cropping(to: crop) else {
            cancel(notify: true)
            return
        }
        dismiss()
        onOutcome?(.image(image))
    }

    private func captureFullScreen(of screen: NSScreen?) {
        let displayID = screen.map(ScreenGeometry.displayID)
        let display =
            session?.displays.first { displayID != nil && $0.displayID == displayID }
            ?? session?.displays.first { $0.screen === screen }
            ?? session?.displays.first
        guard let display else { return }
        dismiss()
        onOutcome?(.image(display.image))
    }

    private func dismiss() {
        isActive = false
        overlayWindows.forEach { $0.orderOut(nil); $0.close() }
        overlayWindows.removeAll()
        toolbarWindow?.orderOut(nil)
        toolbarWindow?.close()
        toolbarWindow = nil
        session = nil
    }

    private func showToolbar(on screen: NSScreen?) {
        let host = NSHostingView(
            rootView: CaptureToolbarView(
                state: state,
                onChooseScreen: { [weak self] in
                    self?.captureFullScreen(
                        of: ScreenGeometry.screen(containing: NSEvent.mouseLocation) ?? screen
                    )
                },
                onCancel: { [weak self] in
                    self?.cancel(notify: true)
                }
            )
        )
        host.frame = NSRect(x: 0, y: 0, width: 360, height: 64)
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        host.frame = NSRect(origin: .zero, size: NSSize(width: max(fitting.width, 320), height: max(fitting.height, 58)))

        let window = NSPanel(
            contentRect: host.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.sharingType = .none
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.animationBehavior = .none
        window.title = "Snippy Toolbar"
        window.identifier = NSUserInterfaceItemIdentifier("snippy.toolbar")
        window.contentView = host
        window.ignoresMouseEvents = false
        window.becomesKeyOnlyIfNeeded = true
        window.worksWhenModal = true

        let target = screen ?? NSScreen.main
        if let target {
            let menuBarHeight = max(target.frame.maxY - target.visibleFrame.maxY, 24)
            let size = host.frame.size
            let origin = NSPoint(
                x: target.frame.midX - size.width / 2,
                y: target.frame.maxY - menuBarHeight - 12 - size.height
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }

        window.orderFrontRegardless()
        toolbarWindow = window
    }
}
