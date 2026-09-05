import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var languageSettings = LanguageSettings.shared

    var body: some View {
        let _ = languageSettings.preference
        Form {
            Picker(L10n.language, selection: $languageSettings.preference) {
                Text(L10n.languageSystem).tag(LanguageSettings.systemCode)
                ForEach(L10n.languages, id: \.code) { language in
                    Text(language.nativeName).tag(language.code)
                }
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(SettingsWindowChrome(title: L10n.settings))
    }
}

private struct SettingsWindowChrome: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = title
        }
    }
}
