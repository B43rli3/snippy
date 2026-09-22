import AppKit
import ApplicationServices

/// Bildschirmaufnahme. Eine schon laufende App behält eine alte Ablehnung, bis ein neuer Prozess die Erlaubnis sieht.
enum PermissionOnboarding {
    static var suppressUI = false

    private static let didOnboardKey = "didShowOnboarding"
    private static var captureVerified = false
    private static var didExplainMissingCapture = false
    private static var watchingGrant = false
    private static var relaunching = false

    static var screenRecordingGranted: Bool {
        captureVerified || CGPreflightScreenCaptureAccess()
    }

    static func promptIfNeeded() {
        if suppressUI { return }
        guard !UserDefaults.standard.bool(forKey: didOnboardKey) else {
            return
        }

        _ = runAlert { alert in
            alert.messageText = L10n.onboardingTitle
            alert.informativeText = L10n.onboardingBody
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.onboardingContinue)
        }

        UserDefaults.standard.set(true, forKey: didOnboardKey)
    }

    static func ensureScreenRecording() async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            captureVerified = true
            UserDefaults.standard.set(0, forKey: relaunchAttemptsKey)
            return true
        }
        if suppressUI || relaunching {
            return false
        }

        // Der laufende Prozess behält die Ablehnung von seinem Start.
        // Ein neuer Prozess sieht den Schalter, den die Nutzerin gerade eingeschaltet hat.
        if freshProcessHasAccess(), consumeRelaunchAttempt() {
            relaunch(captureOnLaunch: true)
            return false
        }

        // Ein Systemdialog für genau diese App. Ein eigenes Fenster kann die Erlaubnis nicht erteilen.
        if !didExplainMissingCapture {
            didExplainMissingCapture = true
            openScreenRecordingSettings()
            watchForGrant()
            requestSystemScreenCapturePrompt()
        }
        return false
    }

    private static let relaunchAttemptsKey = "snippy.relaunchAttempts"

    private static func consumeRelaunchAttempt() -> Bool {
        let attempts = UserDefaults.standard.integer(forKey: relaunchAttemptsKey)
        guard attempts < 2 else { return false }
        UserDefaults.standard.set(attempts + 1, forKey: relaunchAttemptsKey)
        return true
    }

    private static func requestSystemScreenCapturePrompt() {
        let prompt = {
            _ = CGRequestScreenCaptureAccess()
        }
        if Thread.isMainThread {
            prompt()
        } else {
            DispatchQueue.main.sync(execute: prompt)
        }
    }

    /// Prüft einmal pro Sekunde einen neuen Prozess. Steht der Schalter auf An, startet Snippy neu und öffnet die Aufnahme.
    private static func watchForGrant() {
        if watchingGrant { return }
        watchingGrant = true
        let timer = Timer(timeInterval: 1.0, repeats: true) { timer in
            if relaunching {
                timer.invalidate()
                return
            }
            DispatchQueue.global(qos: .utility).async {
                guard freshProcessHasAccess() else { return }
                DispatchQueue.main.async {
                    timer.invalidate()
                    relaunch(captureOnLaunch: true)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func freshProcessHasAccess() -> Bool {
        guard let executable = Bundle.main.executableURL else { return false }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--preflight"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    static func relaunch(captureOnLaunch: Bool = false) {
        if relaunching { return }
        relaunching = true

        // Beenden zuerst erlauben. Sonst blockiert applicationShouldTerminate den Neustart und das Icon bleibt stehen.
        AppDelegate.allowTerminate = true

        if captureOnLaunch {
            UserDefaults.standard.set(true, forKey: "snippy.captureOnLaunch")
        }

        let appURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", appURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()

        // Erst die neue Instanz anstoßen, dann diese beenden.
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    static func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        openFirstAvailable(urls)
    }

    static func showError(_ error: Error) {
        if suppressUI {
            fputs("Snippy error: \(error.localizedDescription)\n", stderr)
            return
        }
        _ = runAlert { alert in
            alert.messageText = L10n.errorTitle
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.errorOK)
        }
    }

    @discardableResult
    static func runAlert(_ configure: (NSAlert) -> Void) -> NSApplication.ModalResponse {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                runAlert(configure)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        configure(alert)
        return alert.runModal()
    }

    private static func openFirstAvailable(_ rawURLs: [String]) {
        for raw in rawURLs {
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
