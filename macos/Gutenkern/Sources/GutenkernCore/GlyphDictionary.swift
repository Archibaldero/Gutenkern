import Foundation

enum GlyphDictionary {
    private static let payload: Payload = load()

    static func `class`(byName name: String) -> String? {
        payload.names[name]
    }

    static func `class`(byChar value: String) -> String? {
        payload.chars[value]
    }

    static func isDigitName(_ name: String) -> Bool {
        payload.names[name] == "digit" || isAsciiDigit(name)
    }

    static func isAsciiDigit(_ value: String) -> Bool {
        value.utf8.count == 1 && value.unicodeScalars.first.map { ("0"..."9").contains($0) } == true
    }

    private struct Payload: Decodable {
        var names: [String: String]
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
        if let url = Bundle.module.url(forResource: "glyph-dictionary", withExtension: "json") {
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
