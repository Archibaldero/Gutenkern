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
    case plain
    case fontlab
    case glyphs
}

public enum KerningGenerator {
    public static func parse(_ input: String) -> [Glyph] {
        var glyphs: [Glyph] = []
        var index = input.startIndex

        while index < input.endIndex {
            let character = input[index]
            if character.isWhitespace {
                index = input.index(after: index)
                continue
            }

            if character == "/" {
                let nameStart = input.index(after: index)
                var nameEnd = nameStart
                while nameEnd < input.endIndex {
                    let next = input[nameEnd]
                    if next == "/" || next.isWhitespace {
                        break
                    }
                    nameEnd = input.index(after: nameEnd)
                }
                let name = String(input[nameStart..<nameEnd])
                if !name.isEmpty {
                    glyphs.append(.name(name))
                }
                index = nameEnd
                continue
            }

            glyphs.append(.character(character))
            index = input.index(after: index)
        }

        return glyphs
    }

    public static func generate(
        left: String,
        right: String,
        mode: PairMode,
        format: OutputFormat
    ) -> String {
        let leftGlyphs = parse(left)
        let rightGlyphs = parse(right)
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

    public static func formatGlyphs(_ glyphs: [Glyph], as format: OutputFormat) -> String {
        switch format {
        case .plain:
            return glyphs.map(plainValue).joined()
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
