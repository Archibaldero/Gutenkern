import AppKit
import Foundation
import GutenkernCore

@main
struct GutenkernCoreCheck {
    static func main() throws {
        let fixturesURL = try resolveFixturesURL()
        let data = try Data(contentsOf: fixturesURL)
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: data)
        var failures = 0

        if fixtures.parse.isEmpty
            || fixtures.generate.isEmpty
            || fixtures.plan.isEmpty
            || fixtures.classify.isEmpty
            || fixtures.generateAll.isEmpty
        {
            fputs("fixtures.json has no cases\n", stderr)
            exit(1)
        }

        for testCase in fixtures.parse {
            let parsed = KerningGenerator.parse(testCase.input)
            let actual = parsed.map { glyph -> [String: String] in
                switch glyph {
                case .character(let character):
                    return ["type": "character", "value": String(character)]
                case .name(let name):
                    return ["type": "name", "value": name]
                }
            }
            let expected = testCase.glyphs.map { ["type": $0.type, "value": $0.value] }
            if actual != expected {
                fputs("PARSE FAIL \(testCase.id)\n  expected: \(expected)\n  actual:   \(actual)\n", stderr)
                failures += 1
            }
        }

        for testCase in fixtures.generate {
            guard let mode = PairMode(rawValue: testCase.mode) else {
                fputs("GENERATE FAIL \(testCase.id): unknown mode \(testCase.mode)\n", stderr)
                failures += 1
                continue
            }
            guard let format = OutputFormat(rawValue: testCase.format) else {
                fputs("GENERATE FAIL \(testCase.id): unknown format \(testCase.format)\n", stderr)
                failures += 1
                continue
            }
            let actual = KerningGenerator.generate(
                left: testCase.left,
                right: testCase.right,
                mode: mode,
                format: format
            )
            if actual != testCase.expected {
                fputs(
                    "GENERATE FAIL \(testCase.id)\n  expected:\n\(testCase.expected)\n  actual:\n\(actual)\n",
                    stderr
                )
                failures += 1
            }
        }

        for testCase in fixtures.plan {
            var selected = Set<KerningGroup>()
            var unknown = false
            for code in testCase.selected {
                guard let group = KerningGroup(rawValue: code) else {
                    fputs("PLAN FAIL \(testCase.id): unknown group \(code)\n", stderr)
                    failures += 1
                    unknown = true
                    break
                }
                selected.insert(group)
            }
            if unknown {
                continue
            }
            let actual = KerningPlan.text(selected: selected)
            if actual != testCase.expected {
                fputs(
                    "PLAN FAIL \(testCase.id)\n  expected:\n\(testCase.expected)\n  actual:\n\(actual)\n",
                    stderr
                )
                failures += 1
            }
        }

        for testCase in fixtures.classify {
            let classified = GlyphClassifier.classify(testCase.input)
            let groups = classified.groups.map(\.rawValue)
            let unknown = classified.unknown.map { token -> String in
                switch token.glyph {
                case .character(let character):
                    return String(character)
                case .name(let name):
                    return name
                }
            }
            if groups != testCase.groups || unknown != testCase.unknown {
                fputs(
                    "CLASSIFY FAIL \(testCase.id)\n  expected groups: \(testCase.groups) unknown: \(testCase.unknown)\n  actual groups:   \(groups) unknown: \(unknown)\n",
                    stderr
                )
                failures += 1
            }
        }

        for testCase in fixtures.generateAll {
            guard let format = OutputFormat(rawValue: testCase.format) else {
                fputs("GENERATEALL FAIL \(testCase.id): unknown format \(testCase.format)\n", stderr)
                failures += 1
                continue
            }
            let actual = KerningGenerator.generate(testCase.input, format: format)
            let joined = KerningGenerator.generateSections(
                GlyphClassifier.classify(testCase.input),
                format: format
            )
            .map { $0.joined(separator: "\n\n") }
            .joined(separator: "\n\n\n")
            if actual != testCase.expected {
                fputs(
                    "GENERATEALL FAIL \(testCase.id)\n  expected:\n\(testCase.expected)\n  actual:\n\(actual)\n",
                    stderr
                )
                failures += 1
            } else if joined != actual {
                fputs("GENERATEALL FAIL \(testCase.id): sections join mismatch\n", stderr)
                failures += 1
            }
        }

        if failures > 0 {
            fputs("\(failures) fixture(s) failed\n", stderr)
            exit(1)
        }

        failures += runSessionSnapshotChecks()
        if failures > 0 {
            fputs("\(failures) session snapshot check(s) failed\n", stderr)
            exit(1)
        }

        failures += runCompletionChecks()
        if failures > 0 {
            fputs("\(failures) completion check(s) failed\n", stderr)
            exit(1)
        }

        let fixtureCount = fixtures.parse.count
            + fixtures.generate.count
            + fixtures.plan.count
            + fixtures.classify.count
            + fixtures.generateAll.count
        print("All \(fixtureCount) fixtures passed")
    }

    private static func resolveFixturesURL() throws -> URL {
        if CommandLine.arguments.count > 1 {
            return URL(fileURLWithPath: CommandLine.arguments[1])
        }

        var directories = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        ]

        while let directory = directories.first {
            directories.removeFirst()
            let candidate = directory.appendingPathComponent("core/fixtures.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path != directory.path {
                directories.append(parent)
            }
        }

        throw CheckError.fixturesNotFound
    }
}

private func runSessionSnapshotChecks() -> Int {
    var failures = 0

    let dirty = SessionSnapshot(
        field1: "AV",
        field2: "ignored",
        groups: ["A", "unknown", "a"],
        completedRecipes: ["A/A/A", "", "a/a/a"],
        completedBlocks: ["H/H/H", "", "A/A"],
        mode: "mirror",
        format: "glyphs"
    ).sanitized()
    if dirty.field1 != "AV" || !dirty.field2.isEmpty || !dirty.groups.isEmpty {
        fputs("SESSION FAIL field/groups: \(dirty.field1) \(dirty.field2) \(dirty.groups)\n", stderr)
        failures += 1
    }
    if dirty.completedRecipes != ["A/A/A", "a/a/a"] {
        fputs("SESSION FAIL recipes: \(dirty.completedRecipes)\n", stderr)
        failures += 1
    }
    if dirty.completedBlocks != ["/A/A", "/H/H/H"] {
        fputs("SESSION FAIL blocks: \(dirty.completedBlocks)\n", stderr)
        failures += 1
    }

    let expanded = SessionSnapshot(completedBlocks: ["H/H/H\nH/O/H"]).sanitized()
    if expanded.completedBlocks != ["/H/H/H", "/H/O/H"] {
        fputs("SESSION FAIL expand pair keys: \(expanded.completedBlocks)\n", stderr)
        failures += 1
    }
    if dirty.pairMode != .simple || dirty.outputFormat != .glyphs {
        fputs("SESSION FAIL mode/format: \(dirty.mode) \(dirty.format)\n", stderr)
        failures += 1
    }

    let unknown = SessionSnapshot(mode: "sideways", format: "otf").sanitized()
    if unknown.pairMode != .simple || unknown.outputFormat != .fontlab {
        fputs("SESSION FAIL unknown mode/format: \(unknown.mode) \(unknown.format)\n", stderr)
        failures += 1
    }

    let legacyPlain = SessionSnapshot(format: "plain").sanitized()
    if legacyPlain.outputFormat != .fontlab || legacyPlain.format != "fontlab" {
        fputs("SESSION FAIL legacy plain format: \(legacyPlain.format)\n", stderr)
        failures += 1
    }

    let emptyJSON = Data("{}".utf8)
    let decoded = SessionSnapshot.decoded(from: emptyJSON)
    if decoded != .empty {
        fputs("SESSION FAIL empty json: \(decoded)\n", stderr)
        failures += 1
    }

    if let data = dirty.encoded() {
        let roundTrip = SessionSnapshot.decoded(from: data)
        if roundTrip != dirty {
            fputs("SESSION FAIL round trip\n", stderr)
            failures += 1
        }
    } else {
        fputs("SESSION FAIL encode\n", stderr)
        failures += 1
    }

    return failures
}

private func runCompletionChecks() -> Int {
    var failures = 0
    let capitals = RecipeSection(
        recipe: "A/A/A",
        groups: ["A/H/A\nA/A/A", "H/A/H\nH/H/H"]
    )
    let lowercase = RecipeSection(
        recipe: "a/a/a",
        groups: ["n/o/n\nn/n/n", "o/n/o\no/o/o"]
    )
    let sections = [capitals, lowercase]

    var completion = KerningCompletion()
    completion.toggleRecipe("A/A/A", sections: sections)
    if !completion.recipes.contains("A/A/A")
        || !completion.isRecipeDone("A/A/A", sections: sections)
        || !capitals.groups.allSatisfy(completion.isBlockDone)
        || completion.recipes.contains("a/a/a")
        || lowercase.groups.contains(where: completion.isBlockDone)
    {
        fputs("COMPLETION FAIL toggle recipe on\n", stderr)
        failures += 1
    }

    completion.toggleRecipe("A/A/A", sections: sections)
    if completion.recipes.contains("A/A/A")
        || completion.isRecipeDone("A/A/A", sections: sections)
        || capitals.groups.contains(where: completion.isBlockDone)
    {
        fputs("COMPLETION FAIL toggle recipe off\n", stderr)
        failures += 1
    }

    completion = KerningCompletion()
    completion.toggleBlock(capitals.groups[0], sections: sections)
    if !completion.isBlockDone(capitals.groups[0]) || completion.isRecipeDone("A/A/A", sections: sections) {
        fputs("COMPLETION FAIL partial groups\n", stderr)
        failures += 1
    }
    completion.toggleBlock(capitals.groups[1], sections: sections)
    if !completion.isRecipeDone("A/A/A", sections: sections) || !completion.recipes.contains("A/A/A") {
        fputs("COMPLETION FAIL all groups mark recipe\n", stderr)
        failures += 1
    }
    completion.toggleBlock(capitals.groups[1], sections: sections)
    if completion.isRecipeDone("A/A/A", sections: sections)
        || !completion.isBlockDone(capitals.groups[0])
        || completion.recipes.contains("A/A/A")
    {
        fputs("COMPLETION FAIL unmark group unmarks recipe\n", stderr)
        failures += 1
    }

    completion = KerningCompletion(recipes: ["A/A/A"])
    completion.sync(sections: sections)
    if !completion.recipes.contains("A/A/A")
        || !capitals.groups.allSatisfy(completion.isBlockDone)
        || lowercase.groups.contains(where: completion.isBlockDone)
    {
        fputs("COMPLETION FAIL sync legacy recipe\n", stderr)
        failures += 1
    }

    completion = KerningCompletion(blocks: Set(capitals.groups))
    completion.sync(sections: sections)
    if !completion.recipes.contains("A/A/A") || completion.recipes.contains("a/a/a") {
        fputs("COMPLETION FAIL sync marks recipe from groups\n", stderr)
        failures += 1
    }

    let generated = KerningGenerator.generateRecipeSections(
        GlyphClassifier.classify("AH"),
        format: .fontlab
    )
    if generated.map(\.recipe) != ["A/A/A"]
        || generated.first?.groups.count != 2
        || generated.map(\.groups) != KerningGenerator.generateSections(
            GlyphClassifier.classify("AH"),
            format: .fontlab
        )
    {
        fputs("COMPLETION FAIL recipe sections identity\n", stderr)
        failures += 1
    }

    let before = KerningGenerator.generateRecipeSections(
        GlyphClassifier.classify("HO"),
        format: .fontlab
    )
    let after = KerningGenerator.generateRecipeSections(
        GlyphClassifier.classify("HOA"),
        format: .fontlab
    )
    let oldKeys = before[0].pairGroups[0].map(\.key)
    let newGroup = after[0].pairGroups.first { $0.first?.key.hasPrefix("/H/") == true } ?? []
    var added = KerningCompletion(blocks: Set(oldKeys))
    added.sync(sections: after)
    if oldKeys.contains(where: { !added.blocks.contains($0) })
        || newGroup.allSatisfy({ added.blocks.contains($0.key) })
    {
        fputs("COMPLETION FAIL add glyph keeps old pairs done\n", stderr)
        failures += 1
    }

    let glyphsSections = KerningGenerator.generateRecipeSections(
        GlyphClassifier.classify("HO"),
        format: .glyphs
    )
    if glyphsSections[0].pairGroups[0].map(\.key) != before[0].pairGroups[0].map(\.key) {
        fputs("COMPLETION FAIL fontlab keys across formats\n", stderr)
        failures += 1
    }

    failures += runMarkChecks()
    failures += runHitTestingChecks()
    failures += runResultLayoutChecks()
    failures += runTokenGlueChecks()
    failures += runSpaceWrapChecks()
    return failures
}

private func runHitTestingChecks() -> Int {
    var failures = 0
    let left = PairHitFrame(key: "/a/a/a", x: 10, y: 5, width: 40, height: 16)
    let right = PairHitFrame(key: "/a/b/a", x: 70, y: 5, width: 40, height: 16)
    let row = [left, right]

    if PairHitTesting.nearestKey(x: 0, y: 0, frames: []) != nil {
        fputs("HIT FAIL empty frames\n", stderr)
        failures += 1
    }
    if PairHitTesting.nearestKey(x: 20, y: 10, frames: row) != "/a/a/a" {
        fputs("HIT FAIL inside left\n", stderr)
        failures += 1
    }
    if PairHitTesting.nearestKey(x: 90, y: 12, frames: row) != "/a/b/a" {
        fputs("HIT FAIL inside right\n", stderr)
        failures += 1
    }
    if PairHitTesting.nearestKey(x: 54, y: 12, frames: row) != "/a/a/a" {
        fputs("HIT FAIL gap left\n", stderr)
        failures += 1
    }
    if PairHitTesting.nearestKey(x: 61, y: 12, frames: row) != "/a/b/a" {
        fputs("HIT FAIL gap right\n", stderr)
        failures += 1
    }
    if PairHitTesting.nearestKey(x: 400, y: 12, frames: row) != "/a/b/a" {
        fputs("HIT FAIL trailing space\n", stderr)
        failures += 1
    }
    if PairHitTesting.nearestKey(x: 2, y: 2, frames: row) != "/a/a/a" {
        fputs("HIT FAIL leading padding\n", stderr)
        failures += 1
    }

    return failures
}

private func runResultLayoutChecks() -> Int {
    var failures = 0
    let sections = KerningGenerator.generateRecipeSections(
        GlyphClassifier.classify("AH"),
        format: .fontlab
    )
    let layout = ResultLayout.build(sections: sections, mode: .column)
    let generated = KerningGenerator.generate(GlyphClassifier.classify("AH"), format: .fontlab)
    if layout.text != generated {
        fputs("LAYOUT FAIL text matches generate\n", stderr)
        failures += 1
    }
    if layout.tokens.isEmpty {
        fputs("LAYOUT FAIL tokens\n", stderr)
        failures += 1
    }
    if layout.categories.isEmpty || layout.categories[0].blocks.isEmpty {
        fputs("LAYOUT FAIL categories\n", stderr)
        failures += 1
    }
    if layout.categoryStarts[.capitals] != 0 {
        fputs("LAYOUT FAIL capitals start\n", stderr)
        failures += 1
    }
    if layout.hasCategory(.lowercase) {
        fputs("LAYOUT FAIL lowercase absent\n", stderr)
        failures += 1
    }
    if layout.token(atUtf16: 0)?.key != layout.tokens.first?.key {
        fputs("LAYOUT FAIL token at 0\n", stderr)
        failures += 1
    }
    let firstGroup = layout.groupKeys(forGroupId: layout.tokens[0].groupId)
    if firstGroup.count < 2 {
        fputs("LAYOUT FAIL group keys\n", stderr)
        failures += 1
    }
    let overlapping = layout.tokens(utf16Start: 0, length: 8)
    if overlapping.isEmpty {
        fputs("LAYOUT FAIL range tokens\n", stderr)
        failures += 1
    }
    let mixed = KerningMarkState(done: [layout.tokens[0].key])
    if !ResultSelectionMarks.canStrike(keys: firstGroup, state: mixed)
        || !ResultSelectionMarks.canUnstrike(keys: firstGroup, state: mixed)
    {
        fputs("LAYOUT FAIL mixed selection marks\n", stderr)
        failures += 1
    }
    let allDone = KerningMarks.markDone(keys: firstGroup, state: KerningMarkState())
    if ResultSelectionMarks.canStrike(keys: firstGroup, state: allDone) {
        fputs("LAYOUT FAIL strike disabled when done\n", stderr)
        failures += 1
    }
    let row = ResultLayout.build(sections: sections, mode: .row)
    if row.tokens.count != layout.tokens.count {
        fputs("LAYOUT FAIL row token count\n", stderr)
        failures += 1
    }
    if row.tokens[0].groupId != row.tokens[1].groupId {
        fputs("LAYOUT FAIL row same group\n", stderr)
        failures += 1
    }
    if row.tokens[1].utf16Start != row.tokens[0].utf16End + 2 {
        fputs("LAYOUT FAIL row two-space join\n", stderr)
        failures += 1
    }
    if let span = row.utf16Range(forGroupId: row.tokens[0].groupId) {
        if span.start != row.tokens[0].utf16Start || span.length < row.tokens[1].utf16End - row.tokens[0].utf16Start {
            fputs("LAYOUT FAIL group utf16 range\n", stderr)
            failures += 1
        }
    } else {
        fputs("LAYOUT FAIL missing group utf16 range\n", stderr)
        failures += 1
    }
    let empty = layout.progress(for: .capitals, done: [])
    if empty.done != 0 {
        fputs("LAYOUT FAIL empty progress\n", stderr)
        failures += 1
    }
    let capitalKeys = Set(layout.tokens.filter { $0.category == .capitals }.map(\.key))
    if empty.total != capitalKeys.count {
        fputs("LAYOUT FAIL capital total\n", stderr)
        failures += 1
    }
    let finished = layout.progress(for: .capitals, done: capitalKeys)
    if finished.done != finished.total {
        fputs("LAYOUT FAIL finished progress\n", stderr)
        failures += 1
    }
    let missing = layout.progress(for: .lowercase, done: capitalKeys)
    if missing.total != 0 || missing.done != 0 {
        fputs("LAYOUT FAIL missing category progress\n", stderr)
        failures += 1
    }
    failures += runNewUnkernedChecks()
    return failures
}

private func runTokenGlueChecks() -> Int {
    var failures = 0
    let token = "/A/B"
    let glued = TokenGlue.apply(token)
    if TokenGlue.strip(glued) != token {
        fputs("GLUE FAIL strip(apply) round-trip\n", stderr)
        failures += 1
    }
    if TokenGlue.clean(glued) != token
        || TokenGlue.clean(glued).contains(TokenGlue.joiner)
        || TokenGlue.clean(glued).contains(TokenGlue.viewSlash)
    {
        fputs("GLUE FAIL clean hides joiner and view slash\n", stderr)
        failures += 1
    }
    if glued == token || !glued.contains(TokenGlue.joiner) || !glued.contains(TokenGlue.viewSlash) {
        fputs("GLUE FAIL apply inserts joiner and view slash\n", stderr)
        failures += 1
    }
    if glued.contains("/") {
        fputs("GLUE FAIL apply removes ascii slash from view\n", stderr)
        failures += 1
    }
    if TokenGlue.apply("") != "" || TokenGlue.apply("A") != "A" {
        fputs("GLUE FAIL empty and single stay plain\n", stderr)
        failures += 1
    }
    let layoutStart = TokenGlue.layoutIndex(fromView: TokenGlue.viewIndex(fromLayout: 2, in: glued), in: glued)
    if layoutStart != 2 {
        fputs("GLUE FAIL view/layout index round-trip\n", stderr)
        failures += 1
    }
    let sections = KerningGenerator.generateRecipeSections(
        GlyphClassifier.classify("AH"),
        format: .fontlab
    )
    let layout = ResultLayout.build(sections: sections, mode: .row)
    if TokenGlue.strip(layout.viewText) != layout.text {
        fputs("GLUE FAIL viewText strips to layout text\n", stderr)
        failures += 1
    }
    if layout.viewText == layout.text {
        fputs("GLUE FAIL viewText differs from layout text\n", stderr)
        failures += 1
    }
    let skipped = TokenGlue.viewText(layoutText: layout.text, tokens: layout.tokens) { _ in false }
    if skipped != layout.text {
        fputs("GLUE FAIL shouldGlue false keeps layout text\n", stderr)
        failures += 1
    }
    if TokenGlue.clean(layout.viewText) != layout.text {
        fputs("GLUE FAIL clean viewText\n", stderr)
        failures += 1
    }
    return failures
}

private func runSpaceWrapChecks() -> Int {
    var failures = 0
    _ = NSApplication.shared
    let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    func measure(_ string: String) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font]).width
    }
    let layout = ResultLayout.build(
        sections: KerningGenerator.generateRecipeSections(
            GlyphClassifier.classify("HЛЧ"),
            format: .fontlab
        ),
        mode: .row
    )
    let view = layout.viewText
    let widths: [CGFloat] = [120, 180, 240, 280]
    for width in widths {
        let fragments = lineFragments(for: view, width: width, font: font)
        for token in layout.tokens {
            if measure(token.display) > width {
                continue
            }
            let glued = TokenGlue.apply(token.display)
            let intact = fragments.contains { fragment in
                fragment.contains(glued)
            }
            if intact {
                continue
            }
            fputs(
                "WRAP FAIL token split \(token.display) width=\(width) fragments=\(fragments.prefix(8))\n",
                stderr
            )
            failures += 1
            return failures
        }
    }
    return failures
}

private func lineFragments(for text: String, width: CGFloat, font: NSFont) -> [String] {
    let storage = NSTextStorage(string: text, attributes: [.font: font])
    let layoutManager = NSLayoutManager()
    let container = NSTextContainer(size: NSSize(width: width, height: 100_000))
    container.lineFragmentPadding = 0
    container.widthTracksTextView = false
    storage.addLayoutManager(layoutManager)
    layoutManager.addTextContainer(container)
    layoutManager.ensureLayout(for: container)
    let glyphCount = layoutManager.numberOfGlyphs
    guard glyphCount > 0 else {
        return []
    }
    var fragments: [String] = []
    var glyphIndex = 0
    while glyphIndex < glyphCount {
        var fragmentRange = NSRange(location: 0, length: 0)
        _ = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &fragmentRange)
        let charRange = layoutManager.characterRange(
            forGlyphRange: fragmentRange,
            actualGlyphRange: nil
        )
        fragments.append((text as NSString).substring(with: charRange))
        glyphIndex = NSMaxRange(fragmentRange)
    }
    return fragments
}

private func runNewUnkernedChecks() -> Int {
    var failures = 0
    let group = "capitals-0"
    let keys: Set<String> = ["/a/a/a", "/a/b/a", "/a/c/a"]
    let current = [group: keys]
    let click = NewUnkernedNotice.update(
        previous: current,
        current: current,
        done: ["/a/a/a"],
        warningGroupIds: [],
        newKeys: []
    )
    if !click.warningGroupIds.isEmpty || !click.newKeys.isEmpty {
        fputs("NOTICE FAIL command click\n", stderr)
        failures += 1
    }

    let grown = NewUnkernedNotice.update(
        previous: [group: ["/a/a/a", "/a/b/a"]],
        current: [group: ["/a/a/a", "/a/b/a", "/a/c/a"]],
        done: ["/a/a/a", "/a/b/a"],
        warningGroupIds: [],
        newKeys: []
    )
    if grown.warningGroupIds != [group] || grown.newKeys != ["/a/c/a"] {
        fputs("NOTICE FAIL new key in done group\n", stderr)
        failures += 1
    }

    let cleared = NewUnkernedNotice.update(
        previous: current,
        current: current,
        done: keys,
        warningGroupIds: [group],
        newKeys: ["/a/c/a"]
    )
    if !cleared.warningGroupIds.isEmpty || !cleared.newKeys.isEmpty {
        fputs("NOTICE FAIL clears when done\n", stderr)
        failures += 1
    }

    let first = NewUnkernedNotice.update(
        previous: [:],
        current: [group: ["/a/a/a", "/a/b/a"]],
        done: ["/a/a/a"],
        warningGroupIds: [],
        newKeys: []
    )
    if !first.warningGroupIds.isEmpty || !first.newKeys.isEmpty {
        fputs("NOTICE FAIL first pass\n", stderr)
        failures += 1
    }
    return failures
}

private func runMarkChecks() -> Int {
    var failures = 0
    let keys = ["H/H/H", "H/O/H", "H/A/H"]

    let emptyDone = KerningMarks.toggleGroup(keys: keys, state: KerningMarkState())
    if emptyDone.groupMark(keys: keys) != .done {
        fputs("MARK FAIL empty group toggle\n", stderr)
        failures += 1
    }

    let cleared = KerningMarks.toggleGroup(keys: keys, state: emptyDone)
    if cleared.groupMark(keys: keys) != .empty || !cleared.done.isEmpty {
        fputs("MARK FAIL done group toggle\n", stderr)
        failures += 1
    }

    let mixed = KerningMarkState(done: ["H/H/H", "H/O/H"])
    if mixed.groupMark(keys: keys) != .mixedDone {
        fputs("MARK FAIL mixed done\n", stderr)
        failures += 1
    }
    let mixedDone = KerningMarks.toggleGroup(keys: keys, state: mixed)
    if mixedDone.groupMark(keys: keys) != .done {
        fputs("MARK FAIL mixed group toggle\n", stderr)
        failures += 1
    }

    var pair = KerningMarks.togglePair(key: "H/A/H", state: KerningMarkState())
    if pair.pairMark("H/A/H") != .done {
        fputs("MARK FAIL pair done\n", stderr)
        failures += 1
    }
    pair = KerningMarks.togglePair(key: "H/A/H", state: pair)
    if pair.pairMark("H/A/H") != .empty {
        fputs("MARK FAIL pair empty\n", stderr)
        failures += 1
    }

    let painted = KerningMarks.markDone(
        keys: ["H/A/H", "H/O/H"],
        state: KerningMarkState(done: ["H/A/H"])
    )
    if painted.done != ["H/A/H", "H/O/H"] {
        fputs("MARK FAIL mark done keeps existing\n", stderr)
        failures += 1
    }

    failures += runHistoryChecks()
    failures += runCopyBurstChecks()

    return failures
}

private func runHistoryChecks() -> Int {
    var failures = 0
    let history = MarkHistory()
    let empty = KerningMarkState()
    let selected = KerningMarkState(done: ["H/A/H"])
    let done = KerningMarkState(done: ["H/A/H", "H/O/H"])

    history.record(from: empty, to: empty)
    if history.canUndo {
        fputs("HISTORY FAIL noop recorded\n", stderr)
        failures += 1
    }

    history.record(from: empty, to: selected)
    history.record(from: selected, to: done)
    guard let firstUndo = history.undo(current: done), firstUndo == selected else {
        fputs("HISTORY FAIL first undo\n", stderr)
        return failures + 1
    }
    guard let secondUndo = history.undo(current: firstUndo), secondUndo == empty else {
        fputs("HISTORY FAIL second undo\n", stderr)
        return failures + 1
    }
    if history.canUndo {
        fputs("HISTORY FAIL extra undo\n", stderr)
        failures += 1
    }
    guard let firstRedo = history.redo(current: secondUndo), firstRedo == selected else {
        fputs("HISTORY FAIL first redo\n", stderr)
        return failures + 1
    }
    history.record(from: firstRedo, to: empty)
    if history.canRedo {
        fputs("HISTORY FAIL redo not cleared\n", stderr)
        failures += 1
    }

    let coalesced = MarkHistory()
    coalesced.beginCoalescing()
    coalesced.record(from: empty, to: selected)
    coalesced.record(from: selected, to: done)
    coalesced.endCoalescing()
    guard let coalescedUndo = coalesced.undo(current: done), coalescedUndo == empty else {
        fputs("HISTORY FAIL coalesced undo\n", stderr)
        return failures + 1
    }
    if coalesced.undo(current: coalescedUndo) != nil {
        fputs("HISTORY FAIL coalesced extra step\n", stderr)
        failures += 1
    }

    return failures
}

private func runCopyBurstChecks() -> Int {
    var failures = 0
    var burst = CopyBurst()
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    if burst.add(key: "H/A/H", at: start) != ["H/A/H"] {
        fputs("BURST FAIL first key\n", stderr)
        failures += 1
    }
    if burst.add(key: "H/O/H", at: start.addingTimeInterval(0.4)) != ["H/A/H", "H/O/H"] {
        fputs("BURST FAIL second key\n", stderr)
        failures += 1
    }
    if burst.add(key: "H/A/H", at: start.addingTimeInterval(0.8)) != ["H/A/H", "H/O/H"] {
        fputs("BURST FAIL duplicate key\n", stderr)
        failures += 1
    }
    if burst.add(key: "H/H/H", at: start.addingTimeInterval(1.8)) != ["H/H/H"] {
        fputs("BURST FAIL window reset\n", stderr)
        failures += 1
    }

    burst.reset()
    if burst.add(key: "H/O/H", at: start.addingTimeInterval(2.0)) != ["H/O/H"] {
        fputs("BURST FAIL explicit reset\n", stderr)
        failures += 1
    }

    return failures
}

private enum CheckError: Error {
    case fixturesNotFound
}

private struct Fixtures: Decodable {
    let parse: [ParseCase]
    let generate: [GenerateCase]
    let plan: [PlanCase]
    let classify: [ClassifyCase]
    let generateAll: [GenerateAllCase]
}

private struct ParseCase: Decodable {
    let id: String
    let input: String
    let glyphs: [GlyphDTO]
}

private struct GlyphDTO: Decodable {
    let type: String
    let value: String
}

private struct GenerateCase: Decodable {
    let id: String
    let left: String
    let right: String
    let mode: String
    let format: String
    let expected: String
}

private struct PlanCase: Decodable {
    let id: String
    let selected: [String]
    let expected: String
}

private struct ClassifyCase: Decodable {
    let id: String
    let input: String
    let groups: [String]
    let unknown: [String]
}

private struct GenerateAllCase: Decodable {
    let id: String
    let input: String
    let format: String
    let expected: String
}
