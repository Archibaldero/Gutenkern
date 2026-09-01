import SwiftUI

struct SettingsView: View {
    @ObservedObject private var languageSettings = LanguageSettings.shared

    var body: some View {
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
    }
}
