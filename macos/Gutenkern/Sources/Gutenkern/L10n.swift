import Combine
import Foundation
import GutenkernCore

final class LanguageSettings: ObservableObject {
    static let shared = LanguageSettings()
    static let systemCode = "system"

    private static let defaultsKey = "interfaceLanguage"

    @Published var preference: String {
        didSet {
            UserDefaults.standard.set(preference, forKey: Self.defaultsKey)
        }
    }

    var resolvedLanguage: String {
        if preference != Self.systemCode, L10n.supported.contains(preference) {
            return preference
        }
        return L10n.systemLanguage
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? Self.systemCode
        if stored == Self.systemCode || L10n.supported.contains(stored) {
            preference = stored
        } else {
            preference = Self.systemCode
        }
    }
}

struct AppLanguage {
    let code: String
    let nativeName: String
}

enum L10n {
    static let supported = ["en", "de", "fr", "pl", "cs", "es", "sv", "it", "uk"]
    static let languages: [AppLanguage] = [
        .init(code: "en", nativeName: "English"),
        .init(code: "de", nativeName: "Deutsch"),
        .init(code: "fr", nativeName: "Français"),
        .init(code: "pl", nativeName: "Polski"),
        .init(code: "cs", nativeName: "Čeština"),
        .init(code: "es", nativeName: "Español"),
        .init(code: "sv", nativeName: "Svenska"),
        .init(code: "it", nativeName: "Italiano"),
        .init(code: "uk", nativeName: "Українська")
    ]

    static var fieldWhat: String { t("fieldWhat") }
    static var fieldWith: String { t("fieldWith") }
    static var type: String { t("type") }
    static var typeSimple: String { t("typeSimple") }
    static var typeMirror: String { t("typeMirror") }
    static var format: String { t("format") }
    static var formatPlain: String { t("formatPlain") }
    static var formatFontLab: String { t("formatFontLab") }
    static var formatGlyphs: String { t("formatGlyphs") }
    static var result: String { t("result") }
    static var copy: String { t("copy") }
    static var copied: String { t("copied") }
    static var save: String { t("save") }
    static var saveEllipsis: String { t("saveEllipsis") }
    static var saveFailed: String { t("saveFailed") }
    static var settings: String { t("settings") }
    static var language: String { t("language") }
    static var languageSystem: String { t("languageSystem") }
    static var groups: String { t("groups") }
    static var plan: String { t("plan") }
    static var help: String { t("help") }
    static var about: String { t("about") }
    static var aboutBody: String { t("aboutBody") }
    static var aboutContact: String { t("aboutContact") }
    static var aboutCopyright: String { t("aboutCopyright") }
    static let authorEmail = "armos1999@gmail.com"
    static let authorWebsite = "arsenmosiichuk.in.ua"
    static var authorEmailURL: URL { URL(string: "mailto:\(authorEmail)")! }
    static var authorWebsiteURL: URL { URL(string: "https://\(authorWebsite)")! }

    static func aboutVersion(_ version: String) -> String {
        t("aboutVersion").replacingOccurrences(of: "{version}", with: version)
    }

    static func groupLabel(_ group: KerningGroup) -> String {
        "\(groupName(group)) (\(group.rawValue))"
    }

    private static func groupName(_ group: KerningGroup) -> String {
        switch group {
        case .capitals: t("groupCapitals")
        case .smallCaps: t("groupSmallCaps")
        case .lowercase: t("groupLowercase")
        case .punctuation: t("groupPunctuation")
        case .nonAlphabetic: t("groupNonAlphabetic")
        case .liningFigures: t("groupLiningFigures")
        case .oldstyleFigures: t("groupOldstyleFigures")
        }
    }

    static let systemLanguage: String = resolveSystemLanguage()

    static func pairCount(_ count: Int) -> String {
        let key: String
        switch plural(count) {
        case .one: key = "pairOne"
        case .few: key = "pairFew"
        case .many: key = "pairMany"
        case .other: key = "pairOther"
        }
        return t(key).replacingOccurrences(of: "{count}", with: String(count))
    }

    private static let catalog: [String: [String: String]] = loadCatalog()

    private static func t(_ key: String) -> String {
        table()[key] ?? key
    }

    private static func table() -> [String: String] {
        let language = LanguageSettings.shared.resolvedLanguage
        var merged = catalog["en"] ?? [:]
        if language != "en", let overlay = catalog[language] {
            merged.merge(overlay) { _, new in new }
        }
        return merged
    }

    private static func resolveSystemLanguage() -> String {
        let candidates = Locale.preferredLanguages + Bundle.main.preferredLocalizations
        for preferred in candidates {
            let code = languageCode(from: preferred)
            if supported.contains(code) {
                return code
            }
        }
        return "en"
    }

    private static func languageCode(from identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-")
        guard let first = normalized.split(separator: "-").first else { return "" }
        return String(first).lowercased()
    }

    private static func loadCatalog() -> [String: [String: String]] {
        guard
            let url = catalogURL(),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else {
            return [:]
        }
        return catalog
    }

    private static func catalogURL() -> URL? {
        if let url = Bundle.main.url(forResource: "l10n", withExtension: "json") {
            return url
        }

        let fromSource = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("core/l10n.json")
        if FileManager.default.fileExists(atPath: fromSource.path) {
            return fromSource
        }
        return nil
    }

    private enum Plural {
        case one, few, many, other
    }

    private static func plural(_ count: Int) -> Plural {
        let n = abs(count)
        switch LanguageSettings.shared.resolvedLanguage {
        case "pl", "uk":
            let n10 = n % 10
            let n100 = n % 100
            if n10 == 1 && n100 != 11 { return .one }
            if (2...4).contains(n10) && !(12...14).contains(n100) { return .few }
            return .many
        case "cs":
            if n == 1 { return .one }
            if (2...4).contains(n) { return .few }
            return .other
        case "fr":
            return n <= 1 ? .one : .other
        default:
            return n == 1 ? .one : .other
        }
    }
}
