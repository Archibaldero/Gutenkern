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
                let slashOffset = utf16Offset
                utf16Offset += character.utf16.count
                index = input.index(after: index)
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
        var sections: [String] = []
        for recipe in KerningPlan.recipes {
            guard
                let left = classified.glyphs(for: recipe.left),
                let right = classified.glyphs(for: recipe.right)
            else {
                continue
            }
            let section = generate(leftGlyphs: left, rightGlyphs: right, mode: recipe.mode, format: format)
            if !section.isEmpty {
                sections.append(section)
            }
        }
        return sections.joined(separator: "\n\n\n")
    }

    public static func generate(
        leftGlyphs: [Glyph],
        rightGlyphs: [Glyph],
        mode: PairMode,
        format: OutputFormat
    ) -> String {
        guard !leftGlyphs.isEmpty, !rightGlyphs.isEmpty else {
            return ""
        }

        var groups: [String] = []
        groups.reserveCapacity(leftGlyphs.count)

        for leftGlyph in leftGlyphs {
            var groupLines: [String] = []
            groupLines.reserveCapacity(rightGlyphs.count)
            for rightGlyph in rightGlyphs {
                let sequence: [Glyph]
                switch mode {
                case .simple:
                    sequence = [leftGlyph, rightGlyph]
                case .mirror:
                    sequence = [leftGlyph, rightGlyph, leftGlyph]
                }
                groupLines.append(formatGlyphs(sequence, as: format))
            }
            groups.append(groupLines.joined(separator: "\n"))
        }

        return groups.joined(separator: "\n\n")
    }

    public static func pairCount(left: String, right: String) -> Int {
        let leftCount = parse(left).count
        let rightCount = parse(right).count
        if leftCount == 0 || rightCount == 0 {
            return 0
        }
        return leftCount * rightCount
    }

    public static func pairCount(_ input: String) -> Int {
        pairCount(GlyphClassifier.classify(input))
    }

    public static func pairCount(_ classified: ClassificationResult) -> Int {
        var total = 0
        for recipe in KerningPlan.recipes {
            guard
                let left = classified.glyphs(for: recipe.left),
                let right = classified.glyphs(for: recipe.right)
            else {
                continue
            }
            total += left.count * right.count
        }
        return total
    }

    public static func formatGlyphs(_ glyphs: [Glyph], as format: OutputFormat) -> String {
        switch format {
        case .fontlab:
            return glyphs.map(plainValue).joined(separator: "/")
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
