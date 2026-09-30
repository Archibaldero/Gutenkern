import Foundation

public enum TokenGlue {
    public static let softBreak = "\u{2028}"
    public static let softBreakUTF16: unichar = 0x2028

    public static func viewSpans(tokens: [ResultToken]) -> [(key: String, range: NSRange)] {
        var spans: [(key: String, range: NSRange)] = []
        spans.reserveCapacity(tokens.count)
        var viewCursor = 0
        var layoutCursor = 0
        for token in tokens {
            let gap = token.utf16Start - layoutCursor
            if gap > 0 {
                viewCursor += gap
            }
            let length = (apply(token.display) as NSString).length
            spans.append((key: token.key, range: NSRange(location: viewCursor, length: length)))
            viewCursor += length
            layoutCursor = token.utf16End
        }
        return spans
    }

    public static func spans(in wrapped: String, tokens: [ResultToken]) -> [(key: String, range: NSRange)] {
        let ns = wrapped as NSString
        var cursor = 0
        var found: [(key: String, range: NSRange)] = []
        found.reserveCapacity(tokens.count)
        for token in tokens {
            let glued = apply(token.display)
            let length = (glued as NSString).length
            while cursor < ns.length {
                if length > 0,
                   cursor + length <= ns.length,
                   ns.substring(with: NSRange(location: cursor, length: length)) == glued {
                    found.append((key: token.key, range: NSRange(location: cursor, length: length)))
                    cursor += length
                    break
                }
                cursor += 1
            }
        }
        return found
    }

    public static func apply(_ text: String) -> String {
        text
    }

    public static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: softBreak, with: "")
    }

    public static func wrapLines(
        _ viewText: String,
        width: CGFloat,
        measure: (String) -> CGFloat
    ) -> String {
        guard width > 1, !viewText.isEmpty else {
            return viewText
        }
        let ns = viewText as NSString
        var output = ""
        var index = 0
        var lineWidth: CGFloat = 0
        var atLineStart = true
        while index < ns.length {
            if isBreakChar(ns.character(at: index)) {
                let separator = readRun(ns, from: &index, while: isBreakChar)
                if separator.contains("\n") || separator.contains("\r") {
                    output += separator
                    lineWidth = 0
                    atLineStart = true
                    continue
                }
                guard index < ns.length else {
                    output += separator
                    break
                }
                let tokenStart = index
                _ = readRun(ns, from: &index, while: { !isBreakChar($0) })
                let token = ns.substring(with: NSRange(location: tokenStart, length: index - tokenStart))
                let separatorWidth = measure(separator)
                let tokenWidth = measure(token)
                if !atLineStart, lineWidth + separatorWidth + tokenWidth > width {
                    output += separator
                    output += softBreak
                    output += token
                    lineWidth = tokenWidth
                } else {
                    output += separator
                    output += token
                    lineWidth += separatorWidth + tokenWidth
                }
                atLineStart = false
                continue
            }
            let tokenStart = index
            _ = readRun(ns, from: &index, while: { !isBreakChar($0) })
            let token = ns.substring(with: NSRange(location: tokenStart, length: index - tokenStart))
            let tokenWidth = measure(token)
            if !atLineStart, lineWidth + tokenWidth > width {
                output += softBreak
                lineWidth = 0
            }
            output += token
            lineWidth += tokenWidth
            atLineStart = false
        }
        return output
    }

    private static func isSkipped(_ utf16: unichar) -> Bool {
        utf16 == softBreakUTF16
    }

    private static func isBreakChar(_ utf16: unichar) -> Bool {
        utf16 == 0x20 || utf16 == 0x0A || utf16 == 0x0D
    }

    private static func readRun(
        _ ns: NSString,
        from index: inout Int,
        while include: (unichar) -> Bool
    ) -> String {
        let start = index
        while index < ns.length, include(ns.character(at: index)) {
            index += 1
        }
        return ns.substring(with: NSRange(location: start, length: index - start))
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
            if !isSkipped(ns.character(at: index)) {
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
            if isSkipped(ns.character(at: index)) {
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
}
