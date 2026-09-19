import AppKit
import GutenkernCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var languageSettings = LanguageSettings.shared
    @ObservedObject private var session = SessionState.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var toastVisible = false
    @State private var toastText = ""
    @State private var toastWork: DispatchWorkItem?
    @State private var keyMonitor: Any?
    @State private var markHistory = MarkHistory()
    @State private var lastActionWasMark = false
    @State private var selectedCategory: KerningGroup?
    @State private var scrollToCategory: KerningGroup?
    @State private var ignoringVisibleSync = false
    @State private var warningGroupIds: Set<String> = []
    @State private var newUnkernedKeys: Set<String> = []
    @State private var previousGroupKeys: [String: Set<String>] = [:]
    @State private var generated = GeneratedCache()

    private var classified: ClassificationResult { generated.classified }
    private var recipeSections: [RecipeSection] { generated.sections }
    private var resultLayout: ResultLayout { generated.layout }
    private var output: String { resultLayout.text }

    private var completion: KerningCompletion {
        KerningCompletion(recipes: session.completedRecipes, blocks: session.completedBlocks)
    }

    private var markState: KerningMarkState {
        KerningMarkState(done: completion.blocks)
    }

    private var totalPairCount: Int {
        resultLayout.tokens.count
    }

    private var donePairCount: Int {
        resultLayout.tokens.reduce(into: 0) { count, token in
            if session.completedBlocks.contains(token.key) {
                count += 1
            }
        }
    }

    private var unknownRanges: [NSRange] {
        classified.unknown.map { NSRange(location: $0.start, length: $0.length) }
    }

    private var categoryProgress: [KerningGroup: (done: Int, total: Int)] {
        resultLayout.progressByCategory(done: session.completedBlocks)
    }

    private static let contentPadding: CGFloat = 20
    private static let fieldGap: CGFloat = 40
    private static let resultTitleToNav: CGFloat = 20
    private static let columnGap: CGFloat = 20
    private static let footerGap: CGFloat = 20
    private static let linkColor = Color(red: 0, green: 170 / 255, blue: 1)

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = generated.refresh(field1: session.field1, format: session.format)
        mainColumn
            .padding(Self.contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(windowFill)
            .background(HideTitleBar())
        .overlay(alignment: .bottom) {
            if toastVisible {
                Text(toastText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78), in: Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: toastVisible)
        .id(languageSettings.preference)
        .frame(minWidth: 720, minHeight: 640)
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                session.persistNow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            session.persistNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            session.persistNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .gutenkernResetProgress)) { _ in
            resetProgress()
        }
        .onAppear {
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handleMarkHistoryKey(event)
                }
            }
            DispatchQueue.main.async {
                syncCompletion()
                promptFormatIfNeeded()
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
        }
        .onChange(of: session.field1) { _ in
            lastActionWasMark = false
            syncCompletion()
        }
        .onChange(of: session.format) { _ in
            syncCompletion()
        }
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: Self.footerGap) {
            Grid(alignment: .topLeading, horizontalSpacing: Self.columnGap, verticalSpacing: Self.fieldGap) {
                GridRow(alignment: .top) {
                    Text(L10n.fieldWhat)
                        .font(.headline)
                        .fixedSize(horizontal: true, vertical: false)
                    NativeTextView(text: $session.field1, unknownRanges: unknownRanges)
                        .frame(minHeight: 88, maxHeight: 100)
                        .frame(maxWidth: .infinity)
                }
                GridRow(alignment: .top) {
                    VStack(alignment: .leading, spacing: Self.resultTitleToNav) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.result)
                                .font(.headline)
                            if totalPairCount > 0 {
                                Text(verbatim: L10n.pairProgress(done: donePairCount, total: totalPairCount))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        categoryNav
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    resultField
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(alignment: .center, spacing: 0) {
                Spacer(minLength: 0)
                Button(L10n.saveEllipsis) {
                    saveResult(open: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(output.isEmpty)
                .keyboardShortcut("s")
                Button(L10n.saveAndOpenEllipsis) {
                    saveResult(open: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(output.isEmpty)
                .padding(.leading, 10)
                Button(L10n.copyAll) {
                    copyAll()
                }
                .buttonStyle(.borderedProminent)
                .tint(Self.linkColor)
                .foregroundStyle(.white)
                .controlSize(.regular)
                .disabled(output.isEmpty)
                .padding(.leading, 10)
            }
        }
    }

    private var windowFill: Color {
        colorScheme == .dark ? Color(nsColor: .textBackgroundColor) : Color.white
    }

    private var categoryNav: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(resultLayout.categories.map(\.group), id: \.self) { group in
                categoryLink(group)
            }
        }
    }

    private func categoryLink(_ group: KerningGroup) -> some View {
        let progress = categoryProgress[group] ?? (0, 0)
        let current = selectedCategory == group
        return Button {
            scrollTo(group)
        } label: {
            Text(L10n.groupSidebarLabel(group, done: progress.done, total: progress.total))
                .foregroundStyle(current ? Color.primary : Self.linkColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
        }
        .buttonStyle(.plain)
        .background(PointingHandCursor())
    }

    private var resultField: some View {
        ResultTextView(
            layout: resultLayout,
            markState: markState,
            newKeys: newUnkernedKeys,
            scrollToCategory: scrollToCategory,
            onStrike: markPairsDone,
            onUnstrike: unstrikeKeys,
            onCopy: copyText,
            onSave: saveText,
            onVisibleCategory: { group in
                guard !ignoringVisibleSync, selectedCategory != group else {
                    return
                }
                selectedCategory = group
            },
            onScrolledToCategory: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    ignoringVisibleSync = false
                    scrollToCategory = nil
                }
            }
        )
    }

    private func scrollTo(_ group: KerningGroup) {
        guard resultLayout.hasCategory(group) else {
            return
        }
        ignoringVisibleSync = true
        selectedCategory = group
        scrollToCategory = group
    }

    private func markPairsDone(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        applyState(KerningMarks.markDone(keys: keys, state: markState))
    }

    private func unstrikeKeys(_ keys: [String]) {
        applyState(ResultSelectionMarks.unstrike(keys: keys, state: markState))
    }

    private func resetProgress() {
        applyState(KerningMarkState())
    }

    private func undoMarks() {
        guard let previous = markHistory.undo(current: markState) else {
            return
        }
        applyState(previous, record: false)
    }

    private func redoMarks() {
        guard let next = markHistory.redo(current: markState) else {
            return
        }
        applyState(next, record: false)
    }

    private func handleMarkHistoryKey(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else {
            return event
        }
        let extras = flags.subtracting([.command, .shift, .capsLock, .numericPad, .function])
        guard extras.isEmpty else {
            return event
        }
        guard event.keyCode == 6 else {
            return event
        }
        guard lastActionWasMark else {
            return event
        }
        if flags.contains(.shift) {
            guard markHistory.canRedo else {
                return event
            }
            redoMarks()
            return nil
        }
        guard markHistory.canUndo else {
            return event
        }
        undoMarks()
        return nil
    }

    private func applyState(_ state: KerningMarkState, record: Bool = true) {
        if record {
            markHistory.record(from: markState, to: state)
            lastActionWasMark = true
        }
        var next = completion
        next.applyDone(state.done, sections: recipeSections)
        apply(next)
        refreshNewUnkerned()
    }

    private func copyAll() {
        copyText(TokenGlue.clean(output))
    }

    private func copyText(_ text: String) {
        copyToPasteboard(text)
        showToast(L10n.groupCopied)
    }

    private func copyToPasteboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showToast(_ text: String) {
        guard !text.isEmpty else { return }
        toastWork?.cancel()
        toastText = text
        toastVisible = true
        let work = DispatchWorkItem {
            toastVisible = false
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func syncCompletion() {
        generated.refresh(field1: session.field1, format: session.format)
        var next = completion
        next.sync(sections: recipeSections)
        if next != completion {
            apply(next)
        }
        refreshNewUnkerned()
    }

    private func refreshNewUnkerned() {
        let current = resultLayout.keysByGroup()
        let updated = NewUnkernedNotice.update(
            previous: previousGroupKeys,
            current: current,
            done: session.completedBlocks,
            warningGroupIds: warningGroupIds,
            newKeys: newUnkernedKeys
        )
        warningGroupIds = updated.warningGroupIds
        newUnkernedKeys = updated.newKeys
        previousGroupKeys = current
    }

    private func apply(_ next: KerningCompletion) {
        session.completedRecipes = next.recipes
        session.completedBlocks = next.blocks
    }

    private func saveText(_ text: String) {
        save(text: text, open: false)
    }

    private func saveResult(open: Bool) {
        save(text: output, open: open)
    }

    private func save(text: String, open: Bool) {
        guard !text.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "kerning.txt"
        panel.prompt = L10n.save
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try TokenGlue.clean(text).write(to: url, atomically: true, encoding: .utf8)
            if open {
                NSWorkspace.shared.open(url)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.saveFailed
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func promptFormatIfNeeded() {
        guard !FormatChoice.hasChosen else {
            return
        }
        FormatChoice.hasChosen = true
        let alert = NSAlert()
        alert.messageText = L10n.chooseFormat
        alert.addButton(withTitle: L10n.formatFontLab)
        alert.addButton(withTitle: L10n.formatGlyphs)
        let response = alert.runModal()
        session.format = response == .alertFirstButtonReturn ? .fontlab : .glyphs
        session.persistNow()
    }
}

private struct HideTitleBar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configure(view.window)
    }

    private func configure(_ window: NSWindow?) {
        guard let window else {
            return
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        let dark = window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        window.backgroundColor = dark ? .textBackgroundColor : .white
    }
}

private struct PointingHandCursor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        CursorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class CursorView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private final class GeneratedCache {
    var field1 = "\u{0}"
    var format = OutputFormat.fontlab
    var classified = GlyphClassifier.classify("")
    var sections: [RecipeSection] = []
    var layout = ResultLayout.empty

    func refresh(field1: String, format: OutputFormat) {
        if self.field1 == field1, self.format == format {
            return
        }
        self.field1 = field1
        self.format = format
        classified = GlyphClassifier.classify(field1)
        sections = KerningGenerator.generateRecipeSections(classified, format: format)
        layout = ResultLayout.build(sections: sections, mode: .row)
    }
}
