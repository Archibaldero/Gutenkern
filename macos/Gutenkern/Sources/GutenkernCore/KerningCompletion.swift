import Foundation

public struct PairLine: Equatable, Hashable, Sendable {
    public let key: String
    public let display: String

    public init(key: String, display: String) {
        self.key = key
        self.display = display
    }
}

public struct RecipeSection: Equatable, Sendable {
    public let recipe: String
    public let pairGroups: [[PairLine]]

    public var groups: [String] {
        pairGroups.map { $0.map(\.display).joined(separator: "\n") }
    }

    public init(recipe: String, groups: [String]) {
        self.recipe = recipe
        self.pairGroups = groups.map { block in
            KerningCompletion.pairKeys(in: block).map { PairLine(key: $0, display: $0) }
        }
    }

    public init(recipe: String, pairGroups: [[PairLine]]) {
        self.recipe = recipe
        self.pairGroups = pairGroups
    }
}

public struct KerningCompletion: Equatable, Sendable {
    public var recipes: Set<String>
    public var blocks: Set<String>

    public init(recipes: Set<String> = [], blocks: Set<String> = []) {
        self.recipes = recipes
        self.blocks = Self.expandPairKeys(blocks)
    }

    public func isRecipeDone(_ recipe: String, sections: [RecipeSection]) -> Bool {
        allGroupsDone(recipe, sections: sections)
    }

    public func isBlockDone(_ block: String) -> Bool {
        isBlockDone(keys: Self.pairKeys(in: block))
    }

    public func isBlockDone(keys: [String]) -> Bool {
        !keys.isEmpty && keys.allSatisfy { blocks.contains($0) }
    }

    public mutating func toggleRecipe(_ recipe: String, sections: [RecipeSection]) {
        let keys = Self.pairKeys(for: recipe, in: sections)
        if isRecipeDone(recipe, sections: sections) {
            recipes.remove(recipe)
            for key in keys {
                blocks.remove(key)
            }
        } else {
            recipes.insert(recipe)
            for key in keys {
                blocks.insert(key)
            }
        }
        syncRecipes(sections: sections)
    }

    public mutating func toggleBlock(_ block: String, sections: [RecipeSection]) {
        toggleKeys(Self.pairKeys(in: block), sections: sections)
    }

    public mutating func toggleKeys(_ keys: [String], sections: [RecipeSection]) {
        if isBlockDone(keys: keys) {
            for key in keys {
                blocks.remove(key)
            }
        } else {
            for key in keys {
                blocks.insert(key)
            }
        }
        syncRecipes(sections: sections)
    }

    public mutating func applyDone(_ done: Set<String>, sections: [RecipeSection]) {
        blocks = Self.expandPairKeys(done)
        syncRecipes(sections: sections)
    }

    public mutating func sync(sections: [RecipeSection]) {
        let known = Self.allPairKeys(sections)
        blocks = blocks.intersection(known)
        for section in sections where !section.pairGroups.isEmpty {
            let keys = Self.pairKeys(in: section)
            let marked = keys.reduce(into: 0) { count, key in
                if blocks.contains(key) {
                    count += 1
                }
            }
            if recipes.contains(section.recipe), marked == 0 {
                for key in keys {
                    blocks.insert(key)
                }
            }
        }
        syncRecipes(sections: sections)
    }

    public mutating func syncRecipes(sections: [RecipeSection]) {
        for section in sections where !section.pairGroups.isEmpty {
            if Self.pairKeys(in: section).allSatisfy({ blocks.contains($0) }) {
                recipes.insert(section.recipe)
            } else {
                recipes.remove(section.recipe)
            }
        }
    }

    public static func pairKeys(in block: String) -> [String] {
        block.split(whereSeparator: \.isNewline).compactMap { line in
            let key = canonicalizePairKey(String(line))
            return key.isEmpty ? nil : key
        }
    }

    public static func pairKeys(in section: RecipeSection) -> [String] {
        section.pairGroups.flatMap { $0.map(\.key) }
    }

    public static func pairKeys(for recipe: String, in sections: [RecipeSection]) -> [String] {
        sections.first { $0.recipe == recipe }.map { pairKeys(in: $0) } ?? []
    }

    public static func allPairKeys(_ sections: [RecipeSection]) -> Set<String> {
        Set(sections.flatMap { pairKeys(in: $0) })
    }

    public static func expandPairKeys(_ blocks: Set<String>) -> Set<String> {
        Set(blocks.flatMap { pairKeys(in: $0) })
    }

    public static func canonicalizePairKey(_ key: String) -> String {
        if key.isEmpty || key.hasPrefix("/") {
            return key
        }
        return "/" + key
    }

    private func allGroupsDone(_ recipe: String, sections: [RecipeSection]) -> Bool {
        let keys = Self.pairKeys(for: recipe, in: sections)
        return !keys.isEmpty && keys.allSatisfy { blocks.contains($0) }
    }
}
