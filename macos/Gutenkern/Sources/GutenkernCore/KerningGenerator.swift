import Foundation

public enum Glyph: Equatable, Sendable {
    case character(Character)
    case name(String)
}

public enum PairMode: String, Equatable, Hashable, Sendable, CaseIterable {
    case simple
    case mirror
}

public enum OutputFormat: String, Equatable, Hashable, Sendable, CaseIterable {
    case fontlab
    case glyphs
}

public enum KerningGenerator {
    public static func parse(_ input: String) -> [Glyph] {
        parseTokens(input).map(\.glyph)
    }

    public static func parseTokens(_ input: String) -> [ParsedToken] {
        var tokens: [ParsedToken] = []
        var index = input.startIndex
        var utf16Offset = 0

        while index < input.endIndex {
            let character = input[index]
            if character.isWhitespace {
                utf16Offset += character.utf16.count
                index = input.index(after: index)
                continue
            }

            if character == "/" {
                let nextIndex = input.index(after: index)
                if nextIndex < input.endIndex, input[nextIndex] == "/" {
                    tokens.append(ParsedToken(
                        glyph: .character("/"),
                        start: utf16Offset,
                        length: 2
                    ))
                    utf16Offset += 2
                    index = input.index(after: nextIndex)
                    continue
                }

                let slashOffset = utf16Offset
                utf16Offset += character.utf16.count
                index = nextIndex
                let nameStart = index
                while index < input.endIndex {
                    let next = input[index]
                    if next == "/" || next.isWhitespace {
                        break
                    }
                    utf16Offset += next.utf16.count
                    index = input.index(after: index)
                }
                let name = String(input[nameStart..<index])
                if !name.isEmpty {
                    tokens.append(ParsedToken(
                        glyph: .name(name),
                        start: slashOffset,
                        length: utf16Offset - slashOffset
                    ))
                }
                continue
            }

            let start = utf16Offset
            let length = character.utf16.count
            tokens.append(ParsedToken(
                glyph: .character(character),
                start: start,
                length: length
            ))
            utf16Offset += length
            index = input.index(after: index)
        }

        return tokens
    }

    public static func generate(
        left: String,
        right: String,
        mode: PairMode,
        format: OutputFormat
    ) -> String {
        generate(leftGlyphs: parse(left), rightGlyphs: parse(right), mode: mode, format: format)
    }

    public static func generate(_ input: String, format: OutputFormat) -> String {
        generate(GlyphClassifier.classify(input), format: format)
    }

    public static func generate(_ classified: ClassificationResult, format: OutputFormat) -> String {
        generateSections(classified, format: format)
            .map { $0.joined(separator: "\n\n") }
            .joined(separator: "\n\n\n")
    }

    public static func generateSections(
        _ classified: ClassificationResult,
        format: OutputFormat
    ) -> [[String]] {
        generateRecipeSections(classified, format: format).map(\.groups)
    }

    public static func generateRecipeSections(
        _ classified: ClassificationResult,
        format: OutputFormat
    ) -> [RecipeSection] {
        var sections: [RecipeSection] = []
        for recipe in KerningPlan.recipes {
            guard
                let left = classified.glyphs(for: recipe.left),
                let right = classified.glyphs(for: recipe.right)
            else {
                continue
            }
            let pairGroups = generatePairGroups(
                leftGlyphs: left,
                rightGlyphs: right,
                mode: recipe.mode,
                format: format,
                letterLetterRecipe: KerningScriptFilter.isLetterGroup(recipe.left)
                    && KerningScriptFilter.isLetterGroup(recipe.right)
            )
            if !pairGroups.isEmpty {
                sections.append(RecipeSection(recipe: recipe.line, pairGroups: pairGroups))
            }
        }
        return sections
    }

    public static func generate(
        leftGlyphs: [Glyph],
        rightGlyphs: [Glyph],
        mode: PairMode,
        format: OutputFormat
    ) -> String {
        generateGroups(
            leftGlyphs: leftGlyphs,
            rightGlyphs: rightGlyphs,
            mode: mode,
            format: format
        ).joined(separator: "\n\n")
    }

    public static func generateGroups(
        leftGlyphs: [Glyph],
        rightGlyphs: [Glyph],
        mode: PairMode,
        format: OutputFormat,
        letterLetterRecipe: Bool = false
    ) -> [String] {
        generatePairGroups(
            leftGlyphs: leftGlyphs,
            rightGlyphs: rightGlyphs,
            mode: mode,
            format: format,
            letterLetterRecipe: letterLetterRecipe
        ).map { $0.map(\.display).joined(separator: "\n") }
    }

    public static func generatePairGroups(
        leftGlyphs: [Glyph],
        rightGlyphs: [Glyph],
        mode: PairMode,
        format: OutputFormat,
        letterLetterRecipe: Bool = false
    ) -> [[PairLine]] {
        guard !leftGlyphs.isEmpty, !rightGlyphs.isEmpty else {
            return []
        }

        var groups: [[PairLine]] = []
        groups.reserveCapacity(leftGlyphs.count)

        for leftGlyph in leftGlyphs {
            var groupLines: [PairLine] = []
            groupLines.reserveCapacity(rightGlyphs.count)
            for rightGlyph in rightGlyphs {
                guard KerningScriptFilter.shouldKern(
                    leftGlyph,
                    rightGlyph,
                    letterLetterRecipe: letterLetterRecipe
                ) else {
                    continue
                }
                let sequence: [Glyph]
                switch mode {
                case .simple:
                    sequence = [leftGlyph, rightGlyph]
                case .mirror:
                    sequence = [leftGlyph, rightGlyph, leftGlyph]
                }
                groupLines.append(
                    PairLine(
                        key: formatGlyphs(sequence, as: .fontlab),
                        display: formatGlyphs(sequence, as: format)
                    )
                )
            }
            if !groupLines.isEmpty {
                groups.append(groupLines)
            }
        }

        return groups
    }

    public static func formatGlyphs(_ glyphs: [Glyph], as format: OutputFormat) -> String {
        switch format {
        case .fontlab:
            guard !glyphs.isEmpty else {
                return ""
            }
            return "/" + glyphs.map(plainValue).joined(separator: "/")
        case .glyphs:
            var result = ""
            var previousWasName = false
            for glyph in glyphs {
                switch glyph {
                case .character(let character):
                    if previousWasName {
                        result.append(" ")
                    }
                    result.append(character)
                    previousWasName = false
                case .name(let name):
                    result.append("/")
                    result.append(name)
                    previousWasName = true
                }
            }
            return result
        }
    }

    private static func plainValue(_ glyph: Glyph) -> String {
        switch glyph {
        case .character(let character):
            return String(character)
        case .name(let name):
            return name
        }
    }
}
