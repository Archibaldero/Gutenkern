import SwiftUI

@main
struct GutenkernApp: App {
    var body: some Scene {
        Window("Gutenkern", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 920, height: 760)
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
}
