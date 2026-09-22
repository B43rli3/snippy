import Foundation

/// Texte zur Laufzeit. Der swiftc-Build lädt keine String-Kataloge, deshalb liegen die Übersetzungen hier.
enum L10n {
    static var usesGerman: Bool {
        if let first = Locale.preferredLanguages.first?.lowercased(), first.hasPrefix("de") {
            return true
        }
        if let langs = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String],
           let first = langs.first?.lowercased(),
           first.hasPrefix("de") {
            return true
        }
        return Locale.current.language.languageCode?.identifier == "de"
    }

    static func text(en: String, de: String) -> String {
        usesGerman ? de : en
    }

    static let appName = "Snippy"

    static var menuShortcut: String { text(en: "Shortcut: ⌃⇧S", de: "Tastenkürzel: ⌃⇧S") }
    static var menuNewCapture: String { text(en: "New Screenshot", de: "Neuer Screenshot") }
    static var menuOpenLast: String { text(en: "Open Last Screenshot", de: "Letzten Screenshot öffnen") }
    static var menuLogin: String { text(en: "Open at Login", de: "Beim Anmelden starten") }
    static var menuScreenRecording: String { text(en: "Allow Screen Recording…", de: "Bildschirmaufnahme erlauben…") }
    static var menuQuit: String { text(en: "Quit Snippy", de: "Snippy beenden") }

    static var toolbarScreen: String { text(en: "Screen", de: "Bildschirm") }
    static var toolbarRegion: String { text(en: "Region", de: "Bereich") }
    static var toolbarWindow: String { text(en: "Window", de: "Fenster") }
    static var toolbarCancel: String { text(en: "Cancel", de: "Abbrechen") }

    static var onboardingTitle: String { text(en: "Welcome to Snippy", de: "Willkommen bei Snippy") }
    static var onboardingContinue: String { text(en: "Continue", de: "Weiter") }
    static var onboardingBody: String {
        text(
            en: "Snippy stays in the menu bar. Press Control+Shift+S to freeze the screen, then choose Screen, Region, or Window. Screenshots are saved to Pictures → Screenshots and copied to the clipboard.\n\nSnippy needs Screen Recording permission. The Globe key is reserved by macOS for Siri, so Snippy does not use Fn+S.",
            de: "Snippy bleibt in der Menüleiste. Mit Steuerung+Umschalt+S wird der Bildschirm eingefroren. Anschließend Bildschirm, Bereich oder Fenster wählen. Screenshots landen in Bilder → Screenshots und in der Zwischenablage.\n\nSnippy braucht die Bildschirmaufnahme. Die Globus-Taste gehört macOS (Siri), deshalb nutzt Snippy nicht Fn+S."
        )
    }

    static var errorTitle: String { appName }
    static var errorOK: String { "OK" }
    static var errorNoDisplays: String { text(en: "No display was found.", de: "Es wurde kein Bildschirm gefunden.") }
    static var errorCaptureFailed: String { text(en: "The screenshot could not be captured.", de: "Der Screenshot konnte nicht aufgenommen werden.") }
    static var savedTitle: String { text(en: "Screenshot saved", de: "Screenshot gespeichert") }
    static var savedDetail: String { text(en: "Copied to the clipboard", de: "In der Zwischenablage") }
}
