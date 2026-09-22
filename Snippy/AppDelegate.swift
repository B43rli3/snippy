import AppKit
import ApplicationServices
import Darwin

/// Menüleisten-App: Shortcut, Einfrieren, Speichern. Beendet sich nur über das Menü oder einen echten Neustart.
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let statusItem = StatusItemController()
    private let hotkey = HotkeyTap()
    private let overlay = CaptureOverlayController()
    private let store = ScreenshotStore()
    private var signalSource: DispatchSourceSignal?
    private var shouldExitAfterCapture = false
    /// Nur Beenden, die Übergabe an /Applications oder ein Neustart dürfen den Prozess wirklich schließen.
    static var allowTerminate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let args = ProcessInfo.processInfo.arguments
        if args.contains("--preflight") {
            exit(CGPreflightScreenCaptureAccess() ? 0 : 2)
        }
        if handOffToInstalledCopy(args) {
            return
        }
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

        statusItem.onQuit = {
            AppDelegate.allowTerminate = true
            NSApp.terminate(nil)
        }
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

        installSignalHook()

        if args.contains("--smoke-overlay") || args.contains("--smoke-region") {
            PermissionOnboarding.suppressUI = true
            shouldExitAfterCapture = true
            let regionSmoke = args.contains("--smoke-region")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                if await PermissionOnboarding.ensureScreenRecording() {
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

        CaptureConfirmation.install()
        PermissionOnboarding.promptIfNeeded()
        hotkey.start()

        let captureOnLaunch = args.contains("--capture-on-launch") || UserDefaults.standard.bool(forKey: "snippy.captureOnLaunch")
        if captureOnLaunch {
            UserDefaults.standard.set(false, forKey: "snippy.captureOnLaunch")
            Task { @MainActor in
                await self.beginCapture()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        hotkey.start()
    }

    /// Spotlight kann die Projektkopie und /Applications/Snippy.app sehen. Nur die installierte App bleibt laufen.
    private func handOffToInstalledCopy(_ args: [String]) -> Bool {
        let installed = URL(fileURLWithPath: "/Applications/Snippy.app")
        let current = Bundle.main.bundleURL.standardizedFileURL
        let isToolLaunch = args.contains("--self-test") || args.contains("--capture-screen") || args.contains("--smoke-overlay") || args.contains("--smoke-region") || args.contains("--preflight")
        guard !isToolLaunch,
              FileManager.default.fileExists(atPath: installed.path),
              current.path != installed.standardizedFileURL.path
        else {
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: installed, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                AppDelegate.allowTerminate = true
                NSApp.terminate(nil)
            }
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.allowTerminate ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        signalSource?.cancel()
        hotkey.stop()
    }

    @MainActor
    private func beginCapture() async {
        guard !overlay.isActive else { return }

        if !(await PermissionOnboarding.ensureScreenRecording()) {
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
        guard await PermissionOnboarding.ensureScreenRecording() else {
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
            CaptureConfirmation.show(image: image, url: url)
        } catch {
            PermissionOnboarding.showError(error)
            if shouldExitAfterCapture { exit(1) }
        }
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
