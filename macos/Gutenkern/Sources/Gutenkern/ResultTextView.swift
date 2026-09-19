import AppKit
import CoreText
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
        syncText(textView, coordinator: context.coordinator, forceAttributes: true)
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
        let viewText = displayedViewText()
        syncText(textView, coordinator: context.coordinator, forceAttributes: false)
        if let group = scrollToCategory, let start = layout.categoryStarts[group] {
            let viewStart = TokenGlue.viewIndex(fromLayout: start, in: viewText)
            DispatchQueue.main.async {
                textView.layoutSubtreeIfNeeded()
                textView.scrollCategoryToTop(utf16Start: viewStart)
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
        let font = Self.resultFont
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

    fileprivate static let resultFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    fileprivate func displayedViewText() -> String {
        layout.viewText
    }

    fileprivate func syncText(
        _ textView: ResultNSTextView,
        coordinator: Coordinator,
        forceAttributes: Bool
    ) {
        let viewText = displayedViewText()
        var rebuilt = false
        if textView.string != viewText {
            let selected = textView.selectedRange
            let oldView = textView.string
            let layoutStart = TokenGlue.layoutIndex(fromView: selected.location, in: oldView)
            let layoutEnd = TokenGlue.layoutIndex(fromView: selected.location + selected.length, in: oldView)
            textView.string = viewText
            let start = TokenGlue.viewIndex(fromLayout: layoutStart, in: viewText)
            let end = TokenGlue.viewIndex(fromLayout: layoutEnd, in: viewText)
            let maxLocation = (viewText as NSString).length
            let location = min(start, maxLocation)
            let length = min(max(0, end - start), max(0, maxLocation - location))
            textView.setSelectedRange(NSRange(location: location, length: length))
            rebuilt = true
        }
        applyAttributes(textView, coordinator: coordinator, viewText: viewText, force: forceAttributes || rebuilt)
    }

    private func applyAttributes(
        _ textView: NSTextView,
        coordinator: Coordinator,
        viewText: String,
        force: Bool
    ) {
        guard let storage = textView.textStorage else {
            return
        }
        let done = markState.done
        let newKeys = newKeys
        if !force,
           coordinator.appliedText == viewText,
           coordinator.appliedDone == done,
           coordinator.appliedNewKeys == newKeys
        {
            return
        }
        let font = Self.resultFont
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
            let range = TokenGlue.viewRange(
                layoutStart: token.utf16Start,
                layoutLength: token.utf16Length,
                in: viewText
            )
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
        applySlashGlyphs(storage, range: full)
        storage.endEditing()
        coordinator.appliedText = viewText
        coordinator.appliedDone = done
        coordinator.appliedNewKeys = newKeys
    }

    private func applySlashGlyphs(_ storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, fontRange, _ in
            guard let font = value as? NSFont,
                  let info = Self.slashGlyphInfo(for: font)
            else {
                return
            }
            let ns = storage.string as NSString
            var index = fontRange.location
            let end = NSMaxRange(fontRange)
            while index < end {
                if ns.character(at: index) == TokenGlue.viewSlashUTF16 {
                    storage.addAttribute(.glyphInfo, value: info, range: NSRange(location: index, length: 1))
                }
                index += 1
            }
        }
    }

    private static func slashGlyphInfo(for font: NSFont) -> NSGlyphInfo? {
        var character: UniChar = 0x002F
        var glyph: CGGlyph = 0
        guard CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1), glyph != 0 else {
            return nil
        }
        return NSGlyphInfo(cgGlyph: glyph, for: font, baseString: String(TokenGlue.viewSlash))
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
            let keys = selectedKeys(in: textView)
            let copyText = cleanCopyText(from: textView)
            let saveText = cleanSaveText(from: textView)

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
            parent.onCopy(cleanCopyText(from: textView))
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
            parent.onSave(cleanSaveText(from: textView))
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
            let layoutIndex = TokenGlue.layoutIndex(fromView: index, in: textView.string)
            parent.onVisibleCategory(parent.layout.category(atUtf16: layoutIndex))
        }

        func writeCleanSelection(from textView: NSTextView, to pboard: NSPasteboard) -> Bool {
            let selection = textView.selectedRange
            guard selection.length > 0 else {
                return false
            }
            let text = TokenGlue.clean((textView.string as NSString).substring(with: selection))
            guard !text.isEmpty else {
                return false
            }
            pboard.declareTypes([.string], owner: nil)
            return pboard.setString(text, forType: .string)
        }

        private func selectedKeys(in textView: NSTextView) -> [String] {
            let mapped = layoutSelection(in: textView)
            return parent.layout.tokens(utf16Start: mapped.location, length: mapped.length).map(\.key)
        }

        private func cleanCopyText(from textView: NSTextView) -> String {
            let selection = textView.selectedRange
            if selection.length > 0 {
                return TokenGlue.clean((textView.string as NSString).substring(with: selection))
            }
            let layoutIndex = TokenGlue.layoutIndex(fromView: selection.location, in: textView.string)
            return parent.layout.token(atUtf16: layoutIndex)?.display ?? ""
        }

        private func cleanSaveText(from textView: NSTextView) -> String {
            let selection = textView.selectedRange
            if selection.length > 0 {
                return TokenGlue.clean((textView.string as NSString).substring(with: selection))
            }
            return parent.layout.text
        }

        private func layoutSelection(in textView: NSTextView) -> NSRange {
            let selection = textView.selectedRange
            let start = TokenGlue.layoutIndex(fromView: selection.location, in: textView.string)
            if selection.length <= 0 {
                return NSRange(location: start, length: 0)
            }
            let end = TokenGlue.layoutIndex(fromView: selection.location + selection.length, in: textView.string)
            return NSRange(location: start, length: max(0, end - start))
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

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: .zero)
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        self.init(frame: .zero, textContainer: container)
    }

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
        if menuItem.action == #selector(copy(_:)) {
            return selectedRange.length > 0
        }
        return menuItem.isEnabled
    }

    override func copy(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        _ = writeSelection(to: pasteboard, types: [.string])
    }

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.string]
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard types.contains(.string) else {
            return false
        }
        return writeSelection(to: pboard, type: .string)
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string else {
            return false
        }
        return coordinator?.writeCleanSelection(from: self, to: pboard) ?? false
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
