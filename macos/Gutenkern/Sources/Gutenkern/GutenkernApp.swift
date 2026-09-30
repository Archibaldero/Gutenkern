import AppKit
import GutenkernCore
import SwiftUI

@main
struct GutenkernApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
            Picker(languageTitle, selection: $languageSettings.preference) {
                Text(L10n.languageSystem).tag(LanguageSettings.systemCode)
                ForEach(L10n.languages, id: \.code) { language in
                    Text(language.nativeName).tag(language.code)
                }
            }
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

    private var languageTitle: String {
        let _ = languageSettings.preference
        return L10n.language
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let window = note.object as? NSWindow,
                      window.identifier?.rawValue == "main" else { return }
                DispatchQueue.main.async {
                    self?.terminateIfNoUserWindows()
                }
            }
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        restoreMainWindows(in: sender)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func restoreMainWindows(in app: NSApplication) {
        for window in app.windows where window.identifier?.rawValue == "main" {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func terminateIfNoUserWindows() {
        let remaining = NSApp.windows.filter { window in
            let id = window.identifier?.rawValue ?? ""
            let isUserWindow = window.canBecomeMain || id == "main" || id == "about"
            return isUserWindow && (window.isVisible || window.isMiniaturized)
        }
        if remaining.isEmpty {
            NSApp.terminate(nil)
        }
    }
}
