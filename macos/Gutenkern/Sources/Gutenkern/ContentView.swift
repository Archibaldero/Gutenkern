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

    private var currentPairKeys: Set<String> {
        Set(resultLayout.tokens.map(\.key))
    }

    private var donePairCount: Int {
        session.completedBlocks.intersection(currentPairKeys).count
    }

    private var unknownRanges: [NSRange] {
        classified.unknown.map { NSRange(location: $0.start, length: $0.length) }
    }

    private var categoryProgress: [KerningGroup: (done: Int, total: Int)] {
        resultLayout.progressByCategory(done: session.completedBlocks)
    }

    private static let groupSpacing: CGFloat = 20

    private var sidebarSelection: Binding<KerningGroup?> {
        Binding(
            get: { selectedCategory },
            set: { newValue in
                guard let newValue else {
                    selectedCategory = nil
                    return
                }
                scrollTo(newValue)
            }
        )
    }

    var body: some View {
        let _ = generated.refresh(field1: session.field1, format: session.format)
        NavigationSplitView {
            categorySidebar
                .navigationSplitViewColumnWidth(min: 196, ideal: 228, max: 300)
        } detail: {
            mainColumn
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .sidebarWindowChrome()
        .background(HideTitleBar())
        .overlay(alignment: .bottom) {
            if toastVisible {
                Text(toastText)
                    .font(.callout)
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

    private var categorySidebar: some View {
        List(selection: sidebarSelection) {
            ForEach(KerningGroup.allCases, id: \.self) { group in
                let progress = categoryProgress[group] ?? (0, 0)
                let available = progress.total > 0
                Text(L10n.groupSidebarLabel(group, done: progress.done, total: progress.total))
                    .foregroundStyle(available ? Color.primary : Color.secondary)
                    .tag(Optional(group))
                    .disabled(!available)
                    .onTapGesture {
                        if available {
                            scrollTo(group)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: Self.groupSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.fieldWhat)
                    .font(.headline)
                NativeTextView(text: $session.field1, unknownRanges: unknownRanges)
                    .frame(minHeight: 88, maxHeight: 100)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.result)
                    .font(.headline)
                resultField
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(alignment: .center, spacing: 0) {
                Text(verbatim: L10n.pairProgress(done: donePairCount, total: totalPairCount))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(totalPairCount == 0 ? 0 : 1)
                Spacer(minLength: 16)
                Button(L10n.copyAll) {
                    copyAll()
                }
                .disabled(output.isEmpty)
                Button(L10n.saveEllipsis) {
                    saveResult(open: false)
                }
                .disabled(output.isEmpty)
                .keyboardShortcut("s")
                .padding(.leading, 10)
                Button(L10n.saveAndOpenEllipsis) {
                    saveResult(open: true)
                }
                .disabled(output.isEmpty)
                .padding(.leading, 10)
            }
        }
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
        copyText(output)
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
            try text.write(to: url, atomically: true, encoding: .utf8)
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
        hideSidebarToggleButton(in: window)
    }

    private func hideSidebarToggleButton(in window: NSWindow) {
        guard let toolbar = window.toolbar else {
            return
        }
        for item in toolbar.items where item.itemIdentifier == .toggleSidebar {
            item.view?.isHidden = true
        }
    }
}

private extension View {
    @ViewBuilder
    func sidebarWindowChrome() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            self
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
