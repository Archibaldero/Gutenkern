import Foundation

public enum TokenGlue {
    public static let joiner = "\u{2060}"
    public static let joinerUTF16: unichar = 0x2060
    public static let viewSlash: Character = "\u{29F8}"
    public static let viewSlashUTF16: unichar = 0x29F8
    public static let asciiSlash: Character = "/"

    public static func apply(_ text: String) -> String {
        guard !text.isEmpty else {
            return text
        }
        var result = ""
        var first = true
        for cluster in text {
            if !first {
                result += joiner
            }
            result.append(cluster == asciiSlash ? viewSlash : cluster)
            first = false
        }
        return result
    }

    public static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: joiner, with: "")
            .replacingOccurrences(of: String(viewSlash), with: String(asciiSlash))
    }

    public static func clean(_ text: String) -> String {
        strip(text)
    }

    public static func viewText(
        layoutText: String,
        tokens: [ResultToken],
        shouldGlue: (ResultToken) -> Bool = { _ in true }
    ) -> String {
        var result = ""
        var cursor = 0
        let ns = layoutText as NSString
        for token in tokens {
            if token.utf16Start > cursor {
                result += ns.substring(
                    with: NSRange(location: cursor, length: token.utf16Start - cursor)
                )
            }
            result += shouldGlue(token) ? apply(token.display) : token.display
            cursor = token.utf16End
        }
        if cursor < ns.length {
            result += ns.substring(from: cursor)
        }
        return result
    }

    public static func layoutIndex(fromView viewIndex: Int, in view: String) -> Int {
        let ns = view as NSString
        let end = min(max(viewIndex, 0), ns.length)
        var layout = 0
        var index = 0
        while index < end {
            if ns.character(at: index) != joinerUTF16 {
                layout += 1
            }
            index += 1
        }
        return layout
    }

    public static func viewIndex(fromLayout layoutIndex: Int, in view: String) -> Int {
        let ns = view as NSString
        var layout = 0
        var index = 0
        while index < ns.length {
            if ns.character(at: index) == joinerUTF16 {
                index += 1
                continue
            }
            if layout >= layoutIndex {
                return index
            }
            layout += 1
            index += 1
        }
        return ns.length
    }

    public static func viewRange(layoutStart: Int, layoutLength: Int, in view: String) -> NSRange {
        let start = viewIndex(fromLayout: layoutStart, in: view)
        let end = viewIndex(fromLayout: layoutStart + layoutLength, in: view)
        return NSRange(location: start, length: max(0, end - start))
    }
}
