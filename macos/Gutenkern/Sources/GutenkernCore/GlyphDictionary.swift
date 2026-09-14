import Foundation

enum GlyphDictionary {
    private static let payload: Payload = load()

    static func `class`(byName name: String) -> String? {
        payload.names[name]?.classification
    }

    static func `class`(byChar value: String) -> String? {
        payload.chars[value]
    }

    static func isDigitName(_ name: String) -> Bool {
        payload.names[name]?.classification == "digit" || isAsciiDigit(name)
    }

    static func isAsciiDigit(_ value: String) -> Bool {
        value.utf8.count == 1 && value.unicodeScalars.first.map { ("0"..."9").contains($0) } == true
    }

    static func script(byName name: String) -> GlyphScript {
        if let entry = payload.names[name] {
            return GlyphScript.fromUnicodeName(entry.unicodeName)
        }
        if let dot = name.firstIndex(of: "."), dot > name.startIndex {
            let base = String(name[..<dot])
            if let entry = payload.names[base] {
                return GlyphScript.fromUnicodeName(entry.unicodeName)
            }
        }
        return .unknown
    }

    static func script(byChar value: String) -> GlyphScript {
        guard let scalar = value.unicodeScalars.first else {
            return .unknown
        }
        return GlyphScript.fromCodePoint(scalar.value)
    }

    private struct NameEntry: Decodable {
        var classification: String
        var unicodeName: String

        enum CodingKeys: String, CodingKey {
            case classification = "class"
            case unicodeName
        }
    }

    private struct Payload: Decodable {
        var names: [String: NameEntry]
        var chars: [String: String]
    }

    private static func load() -> Payload {
        guard let url = resourceURL() else {
            fatalError("glyph-dictionary.json is missing")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            fatalError("glyph-dictionary.json is invalid: \(error)")
        }
    }

    private static func resourceURL() -> URL? {
        if let url = Bundle.main.url(forResource: "glyph-dictionary", withExtension: "json"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let fromSource = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("core/glyph-dictionary.json")
        if FileManager.default.fileExists(atPath: fromSource.path) {
            return fromSource
        }

        return nil
    }
}
