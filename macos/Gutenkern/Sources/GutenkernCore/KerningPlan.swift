import Foundation

public enum KerningGroup: String, CaseIterable, Hashable, Sendable {
    case capitals = "A"
    case smallCaps = "A.sc"
    case lowercase = "a"
    case punctuation = "-"
    case nonAlphabetic = "@"
    case liningFigures = "1p"
    case oldstyleFigures = "1o"
}

public enum KerningPlan {
    public static func rows(selected: Set<KerningGroup>) -> [[String]] {
        var result: [[String]] = []
        var currentBlock: KerningGroup?
        var currentItems: [String] = []
        for recipe in recipes {
            guard selected.contains(recipe.left), selected.contains(recipe.right) else {
                continue
            }
            if currentBlock != recipe.left {
                if !currentItems.isEmpty {
                    result.append(currentItems)
                }
                currentBlock = recipe.left
                currentItems = []
            }
            currentItems.append(recipe.line)
        }
        if !currentItems.isEmpty {
            result.append(currentItems)
        }
        return result
    }

    public static func text(selected: Set<KerningGroup>) -> String {
        rows(selected: selected).map { $0.joined(separator: " ") }.joined(separator: "\n")
    }

    private struct Recipe {
        let left: KerningGroup
        let right: KerningGroup
        let mode: PairMode

        var line: String {
            switch mode {
            case .simple:
                return "\(left.rawValue)/\(right.rawValue)"
            case .mirror:
                return "\(left.rawValue)/\(right.rawValue)/\(left.rawValue)"
            }
        }
    }

    private static let recipes: [Recipe] = [
        Recipe(left: .capitals, right: .capitals, mode: .mirror),
        Recipe(left: .capitals, right: .smallCaps, mode: .simple),
        Recipe(left: .capitals, right: .lowercase, mode: .simple),
        Recipe(left: .capitals, right: .punctuation, mode: .mirror),
        Recipe(left: .capitals, right: .nonAlphabetic, mode: .mirror),
        Recipe(left: .capitals, right: .liningFigures, mode: .mirror),
        Recipe(left: .capitals, right: .oldstyleFigures, mode: .mirror),

        Recipe(left: .smallCaps, right: .smallCaps, mode: .mirror),
        Recipe(left: .smallCaps, right: .punctuation, mode: .mirror),

        Recipe(left: .lowercase, right: .lowercase, mode: .mirror),
        Recipe(left: .lowercase, right: .punctuation, mode: .mirror),
        Recipe(left: .lowercase, right: .nonAlphabetic, mode: .mirror),
        Recipe(left: .lowercase, right: .liningFigures, mode: .mirror),
        Recipe(left: .lowercase, right: .oldstyleFigures, mode: .mirror),

        Recipe(left: .nonAlphabetic, right: .nonAlphabetic, mode: .mirror),
        Recipe(left: .nonAlphabetic, right: .liningFigures, mode: .mirror),
        Recipe(left: .nonAlphabetic, right: .oldstyleFigures, mode: .mirror),

        Recipe(left: .liningFigures, right: .liningFigures, mode: .mirror),
        Recipe(left: .liningFigures, right: .punctuation, mode: .mirror),

        Recipe(left: .oldstyleFigures, right: .oldstyleFigures, mode: .mirror),
        Recipe(left: .oldstyleFigures, right: .punctuation, mode: .mirror)
    ]
}
