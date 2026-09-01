import AppKit
import GutenkernCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var languageSettings = LanguageSettings.shared
    @ObservedObject private var session = SessionState.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var didCopy = false

    private var output: String {
        KerningGenerator.generate(
            left: session.field1,
            right: session.field2,
            mode: session.mode,
            format: session.format
        )
    }

    private var pairCount: Int {
        KerningGenerator.pairCount(left: session.field1, right: session.field2)
    }

    private var planRows: [[String]] {
        KerningPlan.rows(selected: session.selectedGroups)
    }

    private var labelWidth: CGFloat {
        let _ = languageSettings.preference
        let font = NSFont.preferredFont(forTextStyle: .headline)
        let labels = [L10n.groups, L10n.plan, L10n.fieldWhat, L10n.fieldWith, L10n.type, L10n.format, L10n.result]
        let widest = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 116
        return ceil(widest)
    }

    /// Previous grouping: 16/32, then 8/16.
    private static let itemSpacing: CGFloat = 10
    private static let groupSpacing: CGFloat = 20
    private static let labelFieldSpacing: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: Self.groupSpacing) {
            VStack(alignment: .leading, spacing: Self.itemSpacing) {
                HStack(alignment: .top, spacing: Self.labelFieldSpacing) {
                    rowLabel(L10n.groups)
                        .padding(.top, 2)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        ForEach(0 ..< (KerningGroup.allCases.count + 1) / 2, id: \.self) { row in
                            GridRow {
                                groupToggle(KerningGroup.allCases[row * 2])
                                if row * 2 + 1 < KerningGroup.allCases.count {
                                    groupToggle(KerningGroup.allCases[row * 2 + 1])
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: Self.labelFieldSpacing) {
                    rowLabel(L10n.plan)
                        .padding(.top, 4)
                    planField
                }
            }

            VStack(alignment: .leading, spacing: Self.itemSpacing) {
                labeledField(L10n.fieldWhat, text: $session.field1, minHeight: 72)
                labeledField(L10n.fieldWith, text: $session.field2, minHeight: 72)
            }

            VStack(alignment: .leading, spacing: Self.itemSpacing) {
                labeledRow(L10n.type) {
                    Picker(L10n.type, selection: $session.mode) {
                        Text(L10n.typeSimple).tag(PairMode.simple)
                        Text(L10n.typeMirror).tag(PairMode.mirror)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                labeledRow(L10n.format) {
                    Picker(L10n.format, selection: $session.format) {
                        Text(L10n.formatPlain).tag(OutputFormat.plain)
                        Text(L10n.formatFontLab).tag(OutputFormat.fontlab)
                        Text(L10n.formatGlyphs).tag(OutputFormat.glyphs)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: Self.labelFieldSpacing) {
                    rowLabel(L10n.result)
                        .padding(.top, 4)
                    NativeTextView(
                        text: .constant(output),
                        isEditable: false,
                        font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                    )
                    .frame(minHeight: 140)
                }

                Text(L10n.pairCount(pairCount))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, labelWidth + Self.labelFieldSpacing)
            }

            HStack {
                Spacer()
                Button(didCopy ? L10n.copied : L10n.copy) {
                    copyResult()
                }
                .disabled(output.isEmpty)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button(L10n.saveEllipsis) {
                    saveResult()
                }
                .disabled(output.isEmpty)
                .keyboardShortcut("s")
            }
        }
        .id(languageSettings.preference)
        .padding(16)
        .frame(minWidth: 540, minHeight: 760)
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
    }

    @ViewBuilder
    private var planField: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(planRows.enumerated()), id: \.offset) { _, row in
                    FlowLayout(spacing: 8) {
                        ForEach(row, id: \.self) { recipe in
                            planToken(recipe)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Color(nsColor: FieldChrome.background(colorScheme)))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color(nsColor: FieldChrome.border(colorScheme)), lineWidth: 1)
        }
    }

    private func planToken(_ recipe: String) -> some View {
        let done = session.completedRecipes.contains(recipe)
        return Button {
            if session.completedRecipes.contains(recipe) {
                session.completedRecipes.remove(recipe)
            } else {
                session.completedRecipes.insert(recipe)
            }
        } label: {
            Text(recipe)
                .font(.system(size: NSFont.systemFontSize, design: .monospaced))
                .foregroundStyle(done ? Color.primary : Color(nsColor: .linkColor))
                .underline(!done, pattern: .dot)
                .strikethrough(done)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func groupToggle(_ group: KerningGroup) -> some View {
        Toggle(isOn: groupBinding(group)) {
            Text(L10n.groupLabel(group))
                .lineLimit(1)
        }
        .toggleStyle(.checkbox)
    }

    private func groupBinding(_ group: KerningGroup) -> Binding<Bool> {
        Binding(
            get: { session.selectedGroups.contains(group) },
            set: { isOn in
                if isOn {
                    session.selectedGroups.insert(group)
                } else {
                    session.selectedGroups.remove(group)
                }
            }
        )
    }

    @ViewBuilder
    private func labeledField(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Self.labelFieldSpacing) {
            rowLabel(title)
                .padding(.top, 4)
            NativeTextView(text: text)
                .frame(minHeight: minHeight)
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: Self.labelFieldSpacing) {
            rowLabel(title)
            content()
        }
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(width: labelWidth, alignment: .leading)
    }

    private func copyResult() {
        guard !output.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopy = false
        }
    }

    private func saveResult() {
        guard !output.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "kerning.txt"
        panel.prompt = L10n.save
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try output.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.saveFailed
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.origins[index].x, y: bounds.minY + result.origins[index].y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (origins: [CGPoint], sizes: [CGSize], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            width = max(width, x - spacing)
        }

        return (origins, sizes, CGSize(width: width, height: y + rowHeight))
    }
}
