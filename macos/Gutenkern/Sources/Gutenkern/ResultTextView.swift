import AppKit
import GutenkernCore
import SwiftUI

struct ResultTextView: View {
    var layout: ResultLayout
    var markState: KerningMarkState
    var newKeys: Set<String>
    var scrollToCategory: KerningGroup?
    var onStrike: ([String]) -> Void
    var onUnstrike: ([String]) -> Void
    var onCopy: (String) -> Void
    var onSave: (String) -> Void
    var onVisibleCategory: (KerningGroup?) -> Void
    var onScrolledToCategory: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Representable(
                layout: layout,
                markState: markState,
                newKeys: newKeys,
                scrollToCategory: scrollToCategory,
                colorScheme: colorScheme,
                onStrike: onStrike,
                onUnstrike: onUnstrike,
                onCopy: onCopy,
                onSave: onSave,
                onVisibleCategory: onVisibleCategory,
                onScrolledToCategory: onScrolledToCategory
            )
            if layout.isEmpty {
                Text(L10n.resultPlaceholder)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
        .fieldChrome(colorScheme)
    }
}

private struct Representable: NSViewRepresentable {
    var layout: ResultLayout
    var markState: KerningMarkState
    var newKeys: Set<String>
    var scrollToCategory: KerningGroup?
    var colorScheme: ColorScheme
    var onStrike: ([String]) -> Void
    var onUnstrike: ([String]) -> Void
    var onCopy: (String) -> Void
    var onSave: (String) -> Void
    var onVisibleCategory: (KerningGroup?) -> Void
    var onScrolledToCategory: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ResultNSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.coordinator = context.coordinator
        context.coordinator.textView = textView
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        configureScrollView(scrollView)
        configure(textView)
        textView.string = layout.text
        applyAttributes(textView, coordinator: context.coordinator, force: true)
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator = context.coordinator] _ in
            coordinator?.reportVisibleCategory()
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ResultNSTextView else {
            return
        }
        textView.coordinator = context.coordinator
        context.coordinator.textView = textView
        configureScrollView(scrollView)
        configure(textView)
        var rebuilt = false
        if textView.string != layout.text {
            let selected = textView.selectedRange
            textView.string = layout.text
            let maxLocation = (layout.text as NSString).length
            let location = min(selected.location, maxLocation)
            let length = min(selected.length, max(0, maxLocation - location))
            textView.setSelectedRange(NSRange(location: location, length: length))
            rebuilt = true
        }
        applyAttributes(textView, coordinator: context.coordinator, force: rebuilt)
        if let group = scrollToCategory, let start = layout.categoryStarts[group] {
            DispatchQueue.main.async {
                textView.layoutSubtreeIfNeeded()
                textView.scrollCategoryToTop(utf16Start: start)
                onScrolledToCategory()
            }
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
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 4
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.borderWidth = 0
    }

    private func configure(_ textView: NSTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = font
        textView.allowsUndo = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = true
        textView.backgroundColor = FieldChrome.background(colorScheme)
        textView.focusRingType = .none
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.textColor
        ]
    }

    private func applyAttributes(
        _ textView: NSTextView,
        coordinator: Coordinator,
        force: Bool
    ) {
        guard let storage = textView.textStorage else {
            return
        }
        let done = markState.done
        let newKeys = newKeys
        if !force,
           coordinator.appliedText == layout.text,
           coordinator.appliedDone == done,
           coordinator.appliedNewKeys == newKeys
        {
            return
        }
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let bold = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(
            [
                .font: font,
                .foregroundColor: NSColor.textColor,
                .strikethroughStyle: 0
            ],
            range: full
        )
        let doneStyle: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ]
        let newStyle: [NSAttributedString.Key: Any] = [
            .font: bold,
            .foregroundColor: ResultNSTextView.newUnkernedColor,
            .strikethroughStyle: 0
        ]
        for token in layout.tokens {
            let range = NSRange(location: token.utf16Start, length: token.utf16Length)
            let clamped = NSIntersectionRange(range, full)
            guard clamped.length > 0 else {
                continue
            }
            if done.contains(token.key) {
                storage.addAttributes(doneStyle, range: clamped)
            } else if newKeys.contains(token.key) {
                storage.addAttributes(newStyle, range: clamped)
            }
        }
        storage.endEditing()
        coordinator.appliedText = layout.text
        coordinator.appliedDone = done
        coordinator.appliedNewKeys = newKeys
    }

    final class Coordinator {
        var parent: Representable
        fileprivate weak var textView: ResultNSTextView?
        var boundsObserver: NSObjectProtocol?
        var appliedText = "\u{0}"
        var appliedDone: Set<String> = []
        var appliedNewKeys: Set<String> = []
        private var reportingVisible = false

        init(parent: Representable) {
            self.parent = parent
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func menu(for textView: NSTextView) -> NSMenu {
            let menu = NSMenu()
            let selection = textView.selectedRange
            let tokens: [ResultToken]
            if selection.length > 0 {
                tokens = parent.layout.tokens(utf16Start: selection.location, length: selection.length)
            } else {
                tokens = parent.layout.tokens(utf16Start: selection.location, length: 0)
            }
            let keys = tokens.map(\.key)
            let copyText: String
            if selection.length > 0 {
                copyText = (textView.string as NSString).substring(with: selection)
            } else {
                copyText = tokens.first?.display ?? ""
            }
            let saveText = selection.length > 0
                ? (textView.string as NSString).substring(with: selection)
                : parent.layout.text

            let copyItem = NSMenuItem(
                title: L10n.copy,
                action: #selector(ResultNSTextView.copySelection(_:)),
                keyEquivalent: ""
            )
            copyItem.target = textView
            copyItem.isEnabled = !copyText.isEmpty

            let strikeItem = NSMenuItem(
                title: L10n.strikeThrough,
                action: #selector(ResultNSTextView.strikeSelection(_:)),
                keyEquivalent: ""
            )
            strikeItem.target = textView
            strikeItem.isEnabled = ResultSelectionMarks.canStrike(keys: keys, state: parent.markState)

            let unstrikeItem = NSMenuItem(
                title: L10n.clearStrike,
                action: #selector(ResultNSTextView.unstrikeSelection(_:)),
                keyEquivalent: ""
            )
            unstrikeItem.target = textView
            unstrikeItem.isEnabled = ResultSelectionMarks.canUnstrike(keys: keys, state: parent.markState)

            let saveItem = NSMenuItem(
                title: L10n.saveAsFile,
                action: #selector(ResultNSTextView.saveSelection(_:)),
                keyEquivalent: ""
            )
            saveItem.target = textView
            saveItem.isEnabled = !saveText.isEmpty

            menu.items = [copyItem, strikeItem, unstrikeItem, saveItem]
            ResultNSTextView.stripServices(from: menu)
            return menu
        }

        func copySelection(from textView: NSTextView) {
            let selection = textView.selectedRange
            let text: String
            if selection.length > 0 {
                text = (textView.string as NSString).substring(with: selection)
            } else if let token = parent.layout.token(atUtf16: selection.location) {
                text = token.display
            } else {
                text = ""
            }
            parent.onCopy(text)
        }

        func strikeSelection(from textView: NSTextView) {
            let keys = selectedKeys(in: textView)
            guard ResultSelectionMarks.canStrike(keys: keys, state: parent.markState) else {
                return
            }
            parent.onStrike(keys)
        }

        func unstrikeSelection(from textView: NSTextView) {
            let keys = selectedKeys(in: textView)
            guard ResultSelectionMarks.canUnstrike(keys: keys, state: parent.markState) else {
                return
            }
            parent.onUnstrike(keys)
        }

        func saveSelection(from textView: NSTextView) {
            let selection = textView.selectedRange
            let text = selection.length > 0
                ? (textView.string as NSString).substring(with: selection)
                : parent.layout.text
            parent.onSave(text)
        }

        func reportVisibleCategory() {
            guard !reportingVisible else {
                return
            }
            reportingVisible = true
            defer { reportingVisible = false }
            guard let textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                parent.onVisibleCategory(nil)
                return
            }
            if parent.layout.isEmpty {
                parent.onVisibleCategory(nil)
                return
            }
            guard layoutManager.numberOfGlyphs > 0 else {
                parent.onVisibleCategory(parent.layout.category(atUtf16: 0))
                return
            }
            let origin = textView.textContainerOrigin
            let visible = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
            let glyphIndex = layoutManager.glyphIndex(for: visible.origin, in: textContainer)
            let index = layoutManager.characterIndexForGlyph(at: glyphIndex)
            parent.onVisibleCategory(parent.layout.category(atUtf16: index))
        }

        private func selectedKeys(in textView: NSTextView) -> [String] {
            let selection = textView.selectedRange
            return parent.layout.tokens(utf16Start: selection.location, length: selection.length).map(\.key)
        }
    }
}

private final class ResultNSTextView: NSTextView {
    var coordinator: Representable.Coordinator?

    fileprivate static let newUnkernedColor = NSColor(
        srgbRed: 0xFF / 255.0,
        green: 0x40 / 255.0,
        blue: 0x00 / 255.0,
        alpha: 1
    )

    override func setFrameSize(_ newSize: NSSize) {
        var size = newSize
        if let clipWidth = enclosingScrollView?.contentSize.width {
            size.width = max(size.width, clipWidth)
        }
        super.setFrameSize(size)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = coordinator?.menu(for: self)
        if let menu {
            Self.stripServices(from: menu)
        }
        return menu
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        Self.stripServices(from: menu)
    }

    fileprivate static func stripServices(from menu: NSMenu) {
        menu.items.removeAll { item in
            if item.submenu === NSApp.servicesMenu {
                return true
            }
            let identifier = item.identifier?.rawValue ?? ""
            if identifier.localizedCaseInsensitiveContains("service") {
                return true
            }
            return item.title.localizedCaseInsensitiveContains("Services")
                || item.title.localizedCaseInsensitiveContains("Сервіси")
                || item.title.localizedCaseInsensitiveContains("Dienste")
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.isEnabled
    }

    @objc func copySelection(_ sender: Any?) {
        coordinator?.copySelection(from: self)
    }

    @objc func strikeSelection(_ sender: Any?) {
        coordinator?.strikeSelection(from: self)
    }

    @objc func unstrikeSelection(_ sender: Any?) {
        coordinator?.unstrikeSelection(from: self)
    }

    @objc func saveSelection(_ sender: Any?) {
        coordinator?.saveSelection(from: self)
    }

    func scrollCategoryToTop(utf16Start: Int) {
        let length = (string as NSString).length
        guard length > 0, let layoutManager, let textContainer, let scrollView = enclosingScrollView else {
            return
        }
        let start = min(max(utf16Start, 0), length - 1)
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: start, length: 1),
            actualCharacterRange: nil
        )
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.y += textContainerOrigin.y
        let clip = scrollView.contentView
        let maxY = max(0, bounds.height - clip.bounds.height)
        let y = min(max(0, rect.minY - 8), maxY)
        clip.scroll(to: NSPoint(x: 0, y: y))
        scrollView.reflectScrolledClipView(clip)
    }
}
