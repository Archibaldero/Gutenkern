import Foundation

public struct ParsedToken: Equatable, Sendable {
    public var glyph: Glyph
    public var start: Int
    public var length: Int
}

public struct ClassificationResult: Equatable, Sendable {
    public var groups: [KerningGroup]
    public var glyphs: [KerningGroup: [Glyph]]
    public var unknown: [ParsedToken]

    public var groupsText: String {
        groups.map(\.rawValue).joined(separator: " ")
    }

    public func glyphs(for group: KerningGroup) -> [Glyph]? {
        glyphs[group]
    }
}

public enum GlyphClassifier {
    private enum Kind: Equatable {
        case unknown
        case capital
        case lowercase
        case smallCaps
        case punctuation
        case nonAlphabetic
        case liningPlain
        case liningPnum
        case oldstyleOnum
        case oldstyleProportional
    }

    public static func classify(_ input: String) -> ClassificationResult {
        let tokens = KerningGenerator.parseTokens(input)
        var unknown: [ParsedToken] = []
        var tagged: [(Glyph, Kind)] = []

        for token in tokens {
            let kind = classifyToken(token.glyph)
            if kind == .unknown {
                unknown.append(token)
                continue
            }
            tagged.append((token.glyph, kind))
        }

        let hasPnum = tagged.contains { $0.1 == .liningPnum }
        let hasProportionalOldstyle = tagged.contains { $0.1 == .oldstyleProportional }
        var buckets: [KerningGroup: [Glyph]] = [:]
        for group in KerningGroup.allCases {
            buckets[group] = []
        }

        for (glyph, kind) in tagged {
            let group: KerningGroup?
            switch kind {
            case .capital: group = .capitals
            case .lowercase: group = .lowercase
            case .smallCaps: group = .smallCaps
            case .punctuation: group = .punctuation
            case .nonAlphabetic: group = .nonAlphabetic
            case .liningPlain: group = hasPnum ? nil : .liningFigures
            case .liningPnum: group = .liningFigures
            case .oldstyleOnum: group = hasProportionalOldstyle ? nil : .oldstyleFigures
            case .oldstyleProportional: group = .oldstyleFigures
            case .unknown: group = nil
            }
            if let group {
                buckets[group, default: []].append(glyph)
            }
        }

        let present = KerningGroup.allCases.filter { !(buckets[$0] ?? []).isEmpty }
        let glyphs = Dictionary(uniqueKeysWithValues: present.map { ($0, buckets[$0] ?? []) })
        return ClassificationResult(groups: present, glyphs: glyphs, unknown: unknown)
    }

    private static func classifyToken(_ glyph: Glyph) -> Kind {
        switch glyph {
        case .character(let character):
            let value = String(character)
            if let classified = GlyphDictionary.class(byChar: value) {
                return fromDictionary(classified)
            }
            return GlyphDictionary.isAsciiDigit(value) ? .liningPlain : .unknown
        case .name(let name):
            return classifyName(name)
        }
    }

    private static func classifyName(_ name: String) -> Kind {
        let parts = name.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else {
            return .unknown
        }

        let suffixes = Set(parts.dropFirst())
        if suffixes.contains("sc") {
            return .smallCaps
        }

        let hasPnum = suffixes.contains("pnum")
        let hasOnum = suffixes.contains("onum")
        let other = suffixes.filter { $0 != "pnum" && $0 != "onum" }
        if !other.isEmpty {
            if let exact = GlyphDictionary.class(byName: name) {
                return fromDictionary(exact)
            }
            return .unknown
        }

        let baseName = parts[0]
        let isDigit = GlyphDictionary.isDigitName(baseName)
        if hasPnum || hasOnum {
            guard isDigit else {
                return .unknown
            }
            if hasPnum && hasOnum {
                return .oldstyleProportional
            }
            if hasOnum {
                return .oldstyleOnum
            }
            return .liningPnum
        }

        if let classified = GlyphDictionary.class(byName: name) {
            return fromDictionary(classified)
        }
        return .unknown
    }

    private static func fromDictionary(_ classification: String) -> Kind {
        switch classification {
        case "capital": return .capital
        case "lowercase": return .lowercase
        case "digit": return .liningPlain
        case "punctuation": return .punctuation
        case "nonalphabetic": return .nonAlphabetic
        default: return .unknown
        }
    }
}
