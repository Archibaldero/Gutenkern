import SwiftUI

@main
struct GutenkernApp: App {
    var body: some Scene {
        Window("Gutenkern", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 560, height: 760)
        .commands {
            AboutCommands()
        }

        Window(L10n.about, id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
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
    }

    private var aboutTitle: String {
        let _ = languageSettings.preference
        return L10n.about
    }
}
