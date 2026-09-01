import AppKit
import SwiftUI

struct NativeTextView: View {
    @Binding var text: String
    var isEditable: Bool = true
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Representable(text: $text, isEditable: isEditable, font: font, colorScheme: colorScheme)
            .background(Color(nsColor: FieldChrome.background(colorScheme)))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color(nsColor: FieldChrome.border(colorScheme)), lineWidth: 1)
            }
    }
}

private struct Representable: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var font: NSFont
    var colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.string = text
        configure(textView)
        configureScrollView(scrollView)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        configure(textView)
        configureScrollView(scrollView)
        context.coordinator.text = $text
        if textView.string != text {
            textView.string = text
        }
    }

    private func configureScrollView(_ scrollView: NSScrollView) {
        let background = FieldChrome.background(colorScheme)
        scrollView.borderType = .noBorder
        scrollView.focusRingType = .none
        scrollView.drawsBackground = true
        scrollView.backgroundColor = background
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = background
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 4
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.borderWidth = 0
    }

    private func configure(_ textView: NSTextView) {
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = font
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = true
        textView.backgroundColor = FieldChrome.background(colorScheme)
        textView.focusRingType = .none
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

enum FieldChrome {
    static func background(_ scheme: ColorScheme) -> NSColor {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func border(_ scheme: ColorScheme) -> NSColor {
        scheme == .dark ? darkBorder : lightBorder
    }

    private static let lightBackground = nsColor(hex: 0xFAFAFA)
    private static let lightBorder = nsColor(hex: 0xF2F2F2)
    private static let darkBackground = nsColor(hex: 0x191919)
    private static let darkBorder = nsColor(hex: 0x333333)

    private static func nsColor(hex: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1
        )
    }
}
