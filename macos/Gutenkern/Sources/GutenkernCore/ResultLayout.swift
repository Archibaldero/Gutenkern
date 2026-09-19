import Foundation

public struct ResultToken: Equatable, Sendable {
    public let key: String
    public let display: String
    public let groupId: String
    public let category: KerningGroup
    public let utf16Start: Int
    public let utf16Length: Int

    public var utf16End: Int { utf16Start + utf16Length }

    public init(
        key: String,
        display: String,
        groupId: String,
        category: KerningGroup,
        utf16Start: Int,
        utf16Length: Int
    ) {
        self.key = key
        self.display = display
        self.groupId = groupId
        self.category = category
        self.utf16Start = utf16Start
        self.utf16Length = utf16Length
    }
}

public struct ResultGroup: Equatable, Identifiable, Sendable {
    public var id: String { groupId }
    public let groupId: String
    public let category: KerningGroup
    public let pairs: [PairLine]

    public var keys: [String] { pairs.map(\.key) }

    public init(groupId: String, category: KerningGroup, pairs: [PairLine]) {
        self.groupId = groupId
        self.category = category
        self.pairs = pairs
    }
}

public struct ResultCategory: Equatable, Identifiable, Sendable {
    public var id: KerningGroup { group }
    public let group: KerningGroup
    public let blocks: [ResultGroup]

    public init(group: KerningGroup, blocks: [ResultGroup]) {
        self.group = group
        self.blocks = blocks
    }
}

public enum ResultLayoutMode: String, CaseIterable, Sendable {
    case row
    case column
}

public struct ResultLayout: Equatable, Sendable {
    public let text: String
    public let viewText: String
    public let tokens: [ResultToken]
    public let categoryStarts: [KerningGroup: Int]
    public let categories: [ResultCategory]

    public static let empty = ResultLayout(text: "", tokens: [], categoryStarts: [:], categories: [])

    public init(
        text: String,
        tokens: [ResultToken],
        categoryStarts: [KerningGroup: Int],
        categories: [ResultCategory]
    ) {
        self.text = text
        self.tokens = tokens
        self.categoryStarts = categoryStarts
        self.categories = categories
        viewText = TokenGlue.viewText(layoutText: text, tokens: tokens)
    }

    public var isEmpty: Bool { text.isEmpty }

    public func hasCategory(_ group: KerningGroup) -> Bool {
        categoryStarts[group] != nil
    }

    public func progress(for group: KerningGroup, done: Set<String>) -> (done: Int, total: Int) {
        progressByCategory(done: done)[group] ?? (0, 0)
    }

    public func progressByCategory(done: Set<String>) -> [KerningGroup: (done: Int, total: Int)] {
        var totals: [KerningGroup: (done: Int, total: Int)] = [:]
        for token in tokens {
            var entry = totals[token.category, default: (0, 0)]
            entry.total += 1
            if done.contains(token.key) {
                entry.done += 1
            }
            totals[token.category] = entry
        }
        return totals
    }

    public static func build(sections: [RecipeSection], mode: ResultLayoutMode = .column) -> ResultLayout {
        let recipeByLine = Dictionary(uniqueKeysWithValues: KerningPlan.recipes.map { ($0.line, $0) })
        var text = ""
        var tokens: [ResultToken] = []
        var categoryStarts: [KerningGroup: Int] = [:]
        var groupCounters: [KerningGroup: Int] = [:]
        var categories: [ResultCategory] = []
        var currentCategory: KerningGroup?
        var currentBlocks: [ResultGroup] = []
        let pairSeparator = mode == .row ? "  " : "\n"

        func flushCategory() {
            guard let currentCategory, !currentBlocks.isEmpty else {
                return
            }
            categories.append(ResultCategory(group: currentCategory, blocks: currentBlocks))
            currentBlocks = []
        }

        for (sectionIndex, section) in sections.enumerated() {
            if sectionIndex > 0 {
                text += "\n\n\n"
            }
            guard let recipe = recipeByLine[section.recipe] else {
                continue
            }
            let category = recipe.left
            if currentCategory != category {
                flushCategory()
                currentCategory = category
            }
            for (blockIndex, pairs) in section.pairGroups.enumerated() {
                if blockIndex > 0 {
                    text += "\n\n"
                }
                if categoryStarts[category] == nil {
                    categoryStarts[category] = utf16Count(text)
                }
                let index = groupCounters[category, default: 0]
                groupCounters[category] = index + 1
                let groupId = "\(category.rawValue)-\(index)"
                for (pairIndex, pair) in pairs.enumerated() {
                    if pairIndex > 0 {
                        text += pairSeparator
                    }
                    let start = utf16Count(text)
                    let length = utf16Count(pair.display)
                    text += pair.display
                    tokens.append(
                        ResultToken(
                            key: pair.key,
                            display: pair.display,
                            groupId: groupId,
                            category: category,
                            utf16Start: start,
                            utf16Length: length
                        )
                    )
                }
                currentBlocks.append(ResultGroup(groupId: groupId, category: category, pairs: pairs))
            }
        }
        flushCategory()

        return ResultLayout(
            text: text,
            tokens: tokens,
            categoryStarts: categoryStarts,
            categories: categories
        )
    }

    public func token(atUtf16 index: Int) -> ResultToken? {
        for token in tokens {
            if index >= token.utf16Start && index < token.utf16End {
                return token
            }
        }
        return nearestToken(atUtf16: index)
    }

    public func nearestToken(atUtf16 index: Int) -> ResultToken? {
        var best: ResultToken?
        var bestDistance = Int.max
        for token in tokens {
            let distance: Int
            if index < token.utf16Start {
                distance = token.utf16Start - index
            } else if index >= token.utf16End {
                distance = index - token.utf16End + 1
            } else {
                return token
            }
            if distance < bestDistance {
                bestDistance = distance
                best = token
            }
        }
        return best
    }

    public func tokens(utf16Start start: Int, length: Int) -> [ResultToken] {
        if length <= 0 {
            if let token = token(atUtf16: start) {
                return [token]
            }
            return []
        }
        let end = start + length
        return tokens.filter { token in
            token.utf16Start < end && token.utf16End > start
        }
    }

    public func groupKeys(forGroupId groupId: String) -> [String] {
        tokens.filter { $0.groupId == groupId }.map(\.key)
    }

    public func utf16Range(forGroupId groupId: String) -> (start: Int, length: Int)? {
        var first: ResultToken?
        var last: ResultToken?
        for token in tokens where token.groupId == groupId {
            if first == nil {
                first = token
            }
            last = token
        }
        guard let first, let last else {
            return nil
        }
        return (first.utf16Start, last.utf16End - first.utf16Start)
    }

    public func category(atUtf16 index: Int) -> KerningGroup? {
        var match: KerningGroup?
        var bestStart = -1
        for (group, start) in categoryStarts {
            if start <= index, start >= bestStart {
                bestStart = start
                match = group
            }
        }
        return match
    }

    public func keysByGroup() -> [String: Set<String>] {
        var keys: [String: Set<String>] = [:]
        for token in tokens {
            keys[token.groupId, default: []].insert(token.key)
        }
        return keys
    }
}

public enum NewUnkernedNotice {
    public static func update(
        previous: [String: Set<String>],
        current: [String: Set<String>],
        done: Set<String>,
        warningGroupIds: Set<String>,
        newKeys: Set<String>
    ) -> (warningGroupIds: Set<String>, newKeys: Set<String>) {
        var warning = warningGroupIds
        var news = newKeys
        let firstPass = previous.isEmpty
        for (groupId, keys) in current {
            if !isMixed(keys: keys, done: done) {
                warning.remove(groupId)
                news.subtract(keys)
                continue
            }
            if firstPass {
                continue
            }
            let before = previous[groupId] ?? []
            let added = keys.subtracting(before)
            let hadDone = !before.intersection(done).isEmpty
            if !added.isEmpty, hadDone {
                warning.insert(groupId)
                news.formUnion(added)
            }
        }
        warning = warning.filter { current[$0] != nil }
        let known = Set(current.values.flatMap { $0 })
        news = news.intersection(known)
        return (warning, news)
    }

    private static func isMixed(keys: Set<String>, done: Set<String>) -> Bool {
        guard !keys.isEmpty else {
            return false
        }
        let doneCount = keys.reduce(into: 0) { count, key in
            if done.contains(key) {
                count += 1
            }
        }
        return doneCount > 0 && doneCount < keys.count
    }
}

public enum ResultSelectionMarks {
    public static func canStrike(keys: [String], state: KerningMarkState) -> Bool {
        keys.contains { state.pairMark($0) == .empty }
    }

    public static func canUnstrike(keys: [String], state: KerningMarkState) -> Bool {
        keys.contains { state.pairMark($0) == .done }
    }

    public static func strike(keys: [String], state: KerningMarkState) -> KerningMarkState {
        KerningMarks.markDone(keys: keys, state: state)
    }

    public static func unstrike(keys: [String], state: KerningMarkState) -> KerningMarkState {
        var next = state
        for key in keys {
            next.done.remove(key)
        }
        return next
    }
}

private func utf16Count(_ string: String) -> Int {
    (string as NSString).length
}
