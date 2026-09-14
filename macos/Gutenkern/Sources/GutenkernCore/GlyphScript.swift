import Foundation

enum GlyphScript: Equatable, Sendable {
    case latin
    case cyrillic
    case greek
    case unknown

    static func fromUnicodeName(_ unicodeName: String) -> GlyphScript {
        guard let first = unicodeName.split(whereSeparator: { $0.isWhitespace }).first else {
            return .unknown
        }
        switch first {
        case "LATIN", "FEMININE", "MASCULINE":
            return .latin
        case "CYRILLIC":
            return .cyrillic
        case "GREEK":
            return .greek
        default:
            return .unknown
        }
    }

    static func fromCodePoint(_ value: UInt32) -> GlyphScript {
        if (0x0370...0x03FF).contains(value) || (0x1F00...0x1FFF).contains(value) {
            return .greek
        }
        if (0x0400...0x052F).contains(value)
            || (0x2DE0...0x2DFF).contains(value)
            || (0xA640...0xA69F).contains(value)
        {
            return .cyrillic
        }
        if (0x0000...0x02AF).contains(value)
            || (0x1E00...0x1EFF).contains(value)
            || (0x2C60...0x2C7F).contains(value)
            || (0xA720...0xA7FF).contains(value)
            || (0xAB30...0xAB6F).contains(value)
        {
            return .latin
        }
        return .unknown
    }
}

enum KerningScriptFilter {
    static func isLetterGroup(_ group: KerningGroup) -> Bool {
        switch group {
        case .capitals, .smallCaps, .lowercase:
            return true
        case .punctuation, .nonAlphabetic, .liningFigures, .oldstyleFigures:
            return false
        }
    }

    static func shouldKern(_ left: Glyph, _ right: Glyph, letterLetterRecipe: Bool) -> Bool {
        guard letterLetterRecipe else {
            return true
        }
        let leftScript = script(of: left)
        let rightScript = script(of: right)
        if leftScript == .unknown || rightScript == .unknown {
            return true
        }
        return leftScript == rightScript
    }

    static func pairCount(left: [Glyph], right: [Glyph], letterLetterRecipe: Bool) -> Int {
        if !letterLetterRecipe {
            return left.count * right.count
        }
        var total = 0
        for leftGlyph in left {
            for rightGlyph in right where shouldKern(leftGlyph, rightGlyph, letterLetterRecipe: true) {
                total += 1
            }
        }
        return total
    }

    private static func script(of glyph: Glyph) -> GlyphScript {
        switch glyph {
        case .character(let character):
            return GlyphDictionary.script(byChar: String(character))
        case .name(let name):
            return GlyphDictionary.script(byName: name)
        }
    }
}
