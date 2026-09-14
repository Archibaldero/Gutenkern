import GutenkernCore
import SwiftUI

@main
struct GutenkernApp: App {
    var body: some Scene {
        Window("", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 760)
        .commands {
            AboutCommands()
        }

        Window(L10n.about, id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window(L10n.settings, id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

private struct AboutCommands: Commands {
    @ObservedObject private var languageSettings = LanguageSettings.shared
    @ObservedObject private var session = SessionState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .appInfo) {
            Button(aboutTitle) {
                openWindow(id: "about")
            }
        }
        CommandGroup(replacing: .appSettings) {
            Button(settingsTitle) {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Picker(formatTitle, selection: $session.format) {
                Text(L10n.formatFontLab).tag(OutputFormat.fontlab)
                Text(L10n.formatGlyphs).tag(OutputFormat.glyphs)
            }
            Button(resetTitle) {
                NotificationCenter.default.post(name: .gutenkernResetProgress, object: nil)
            }
            .disabled(!session.hasProgress)
        }
    }

    private var aboutTitle: String {
        let _ = languageSettings.preference
        return L10n.about
    }

    private var settingsTitle: String {
        let _ = languageSettings.preference
        return L10n.settings
    }

    private var formatTitle: String {
        let _ = languageSettings.preference
        return L10n.format
    }

    private var resetTitle: String {
        let _ = languageSettings.preference
        return L10n.resetProgress
    }
}
