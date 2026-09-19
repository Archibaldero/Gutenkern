import AppKit
import SwiftUI

struct AboutView: View {
    @ObservedObject private var languageSettings = LanguageSettings.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        let _ = languageSettings.preference
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                Text("Gutenkern")
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)

            Text(L10n.aboutBodyText())
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.aboutVersionText(version))
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.aboutCreditsText())
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: true, vertical: true)
        .background(AboutWindowChrome(title: L10n.about))
    }
}

private struct AboutWindowChrome: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = title
            window.isRestorable = false
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }
}
