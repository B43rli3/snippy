import AppKit
import Darwin

/// Einstieg. Der Selbsttest beendet sich, bevor die Menüleiste startet.

@main
enum SnippyMain {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--self-test") {
            _ = NSApplication.shared
            let ok = SelfTest.runUnitTests()
            Darwin.exit(ok ? 0 : 1)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
