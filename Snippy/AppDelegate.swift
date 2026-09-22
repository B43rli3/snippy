import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let statusItem = StatusItemController()
    private let hotkey = HotkeyTap()
    private let overlay = CaptureOverlayController()
    private let store = ScreenshotStore()
    private var accessibilityWatch: DispatchSourceTimer?
    private var signalSource: DispatchSourceSignal?
    private var shouldExitAfterCapture = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let args = ProcessInfo.processInfo.arguments
        if args.contains("--self-test") {
            PermissionOnboarding.suppressUI = true
            let ok = SelfTest.runUnitTests()
            exit(ok ? 0 : 1)
        }

        if args.contains("--capture-screen") {
            PermissionOnboarding.suppressUI = true
            shouldExitAfterCapture = true
            Task { @MainActor in
                await self.captureFullScreenWithoutOverlay()
            }
            return
        }

        statusItem.onQuit = { NSApp.terminate(nil) }
        statusItem.onOpenLast = { [weak self] in
            self?.store.openLast()
        }
        statusItem.onNewCapture = { [weak self] in
            Task { @MainActor in
                await self?.beginCapture()
            }
        }
        statusItem.lastScreenshotExists = { [weak self] in
            self?.store.lastScreenshotURL != nil
        }
        statusItem.onRetryHotkey = { [weak self] in
            self?.hotkey.start()
        }
        statusItem.install()

        overlay.onOutcome = { [weak self] outcome in
            guard let self else { return }
            Task { @MainActor in
                await self.handle(outcome)
            }
        }

        hotkey.onTrigger = { [weak self] in
            Task { @MainActor in
                await self?.beginCapture()
            }
        }
        hotkey.onEscape = { [weak self] in
            self?.overlay.handleEscape() ?? false
        }

        installSignalHook()
        startAccessibilityWatch()

        if args.contains("--smoke-overlay") || args.contains("--smoke-region") {
            PermissionOnboarding.suppressUI = true
            shouldExitAfterCapture = true
            let regionSmoke = args.contains("--smoke-region")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                if PermissionOnboarding.ensureScreenRecording() {
                    await self.beginCapture()
                } else {
                    self.overlay.present(ScreenCaptureService.syntheticSession())
                }
                try? await Task.sleep(for: .milliseconds(400))
                guard self.overlay.isActive else {
                    Darwin.exit(4)
                }
                if regionSmoke {
                    self.overlay.captureTestRegion(NSRect(x: 80, y: 80, width: 220, height: 140))
                } else {
                    self.overlay.captureActiveScreenForTest()
                }
            }
            return
        }

        PermissionOnboarding.promptIfNeeded()
        hotkey.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        hotkey.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityWatch?.cancel()
        signalSource?.cancel()
        hotkey.stop()
    }

    @MainActor
    private func beginCapture() async {
        guard !overlay.isActive else { return }

        if !PermissionOnboarding.ensureScreenRecording() {
            return
        }

        do {
            let session = try await ScreenCaptureService.freeze()
            overlay.present(session)
        } catch {
            PermissionOnboarding.showError(error)
        }
    }

    @MainActor
    private func captureFullScreenWithoutOverlay() async {
        guard PermissionOnboarding.ensureScreenRecording() else {
            fputs("Snippy: screen recording permission missing\n", stderr)
            if shouldExitAfterCapture { exit(2) }
            return
        }
        do {
            let session = try await ScreenCaptureService.freeze()
            let mouseScreen = ScreenGeometry.screen(containing: NSEvent.mouseLocation)
            let displayID = mouseScreen.map(ScreenGeometry.displayID)
            let display =
                session.displays.first { displayID != nil && $0.displayID == displayID }
                ?? session.displays.first
            guard let display else {
                throw CaptureError.noDisplays
            }
            let url = try store.save(display.image)
            print("Saved \(url.path)")
            if shouldExitAfterCapture { exit(0) }
        } catch {
            PermissionOnboarding.showError(error)
            if shouldExitAfterCapture { exit(1) }
        }
    }

    @MainActor
    private func handle(_ outcome: OverlayOutcome) async {
        switch outcome {
        case .cancel:
            if shouldExitAfterCapture { exit(3) }
        case .image(let image):
            save(image)
        }
    }

    @MainActor
    private func save(_ image: CGImage) {
        do {
            let url = try store.save(image)
            if shouldExitAfterCapture {
                print("Saved \(url.path)")
                exit(0)
            }
        } catch {
            PermissionOnboarding.showError(error)
            if shouldExitAfterCapture { exit(1) }
        }
    }

    private func startAccessibilityWatch() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.5, repeating: 1.5)
        timer.setEventHandler { [weak self] in
            guard let self else {
                timer.cancel()
                return
            }
            self.hotkey.start()
            if self.hotkey.isRunning {
                timer.cancel()
                self.accessibilityWatch = nil
            }
        }
        timer.resume()
        accessibilityWatch = timer
    }

    private func installSignalHook() {
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                Task { @MainActor in
                    await self?.beginCapture()
                }
            }
        }
        source.resume()
        signalSource = source
    }
}
