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
    static var groupCopied: String { t("groupCopied") }
    static var format: String { t("format") }
    static var formatFontLab: String { t("formatFontLab") }
    static var formatGlyphs: String { t("formatGlyphs") }
    static var result: String { t("result") }
    static var copy: String { t("copy") }
    static var save: String { t("save") }
    static var saveEllipsis: String { t("saveEllipsis") }
    static var saveAndOpenEllipsis: String { t("saveAndOpenEllipsis") }
    static var saveAsFile: String { t("saveAsFile") }
    static var saveFailed: String { t("saveFailed") }
    static var copyAll: String { t("copyAll") }
    static var strikeThrough: String { t("strikeThrough") }
    static var clearStrike: String { t("clearStrike") }
    static var resultPlaceholder: String { t("resultPlaceholder") }
    static var chooseFormat: String { t("chooseFormat") }
    static var resetProgress: String { t("resetProgress") }
    static var settings: String { t("settings") }
    static var language: String { t("language") }
    static var languageSystem: String { t("languageSystem") }
    static var about: String { t("about") }
    static var aboutBody: String { t("aboutBody") }
    static var aboutCredits: String { t("aboutCredits") }
    static var appName: String { t("appName") }
    static var arsenName: String { t("arsenName") }
    static var vladName: String { t("vladName") }
    static var oleksiiName: String { t("oleksiiName") }
    static let authorEmail = "armos1999@gmail.com"
    static let authorWebsite = "arsenmosiichuk.in.ua"
    static let vladWebsite = "zahrevsky.com"
    static let oleksiiWebsite = "oleksii.shmalko.com"
    static let updatesPath = "arsenmosiichuk.in.ua/gutenkern"
    static var authorEmailURL: URL { URL(string: "mailto:\(authorEmail)")! }
    static var authorWebsiteURL: URL { URL(string: "https://\(authorWebsite)")! }
    static var vladWebsiteURL: URL { URL(string: "https://\(vladWebsite)")! }
    static var oleksiiWebsiteURL: URL { URL(string: "https://\(oleksiiWebsite)")! }
    static var updatesURL: URL { URL(string: "https://\(updatesPath)")! }

    static func aboutBodyText() -> AttributedString {
        AttributedString(aboutBody.replacingOccurrences(of: "{appName}", with: appName))
    }

    static func aboutVersionText(_ version: String) -> AttributedString {
        let template = t("aboutVersion").replacingOccurrences(of: "{version}", with: version)
        return attributedTemplate(template, replacements: [
            "{updatesUrl}": (updatesPath, updatesURL)
        ])
    }

    static func aboutCreditsText() -> AttributedString {
        var text = attributedTemplate(aboutCredits, replacements: [
            "{arsenName}": (arsenName, authorWebsiteURL),
            "{vladName}": (vladName, vladWebsiteURL),
            "{oleksiiName}": (oleksiiName, oleksiiWebsiteURL)
        ])
        text.append(AttributedString(" "))
        var email = AttributedString(authorEmail)
        email.link = authorEmailURL
        text.append(email)
        text.append(AttributedString("."))
        return text
    }

    static func groupLabel(_ group: KerningGroup) -> String {
        groupName(group)
    }

    static func groupSidebarLabel(_ group: KerningGroup, done: Int, total: Int) -> String {
        var label = groupLabel(group)
        guard total > 0 else {
            return label
        }
        label += " ⋅ \(groupedCount(done))/\(groupedCount(total))"
        if done == total {
            label += " ✓"
        }
        return label
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
        return t(key).replacingOccurrences(of: "{count}", with: groupedCount(count))
    }

    static func pairProgress(done: Int, total: Int) -> String {
        let progress = "\(groupedCount(done))/\(groupedCount(total))"
        var label = pairCount(total).replacingOccurrences(of: groupedCount(total), with: progress)
        if total > 0, done == total {
            label += " ✓"
        }
        return label
    }

    static func groupedCount(_ count: Int) -> String {
        let sign = count < 0 ? "-" : ""
        let digits = Array(String(abs(count)))
        var grouped: [Character] = []
        for (index, digit) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 {
                grouped.append("\u{202F}")
            }
            grouped.append(digit)
        }
        return sign + String(grouped.reversed())
    }

    private static func attributedTemplate(
        _ template: String,
        replacements: [String: (String, URL)]
    ) -> AttributedString {
        var result = AttributedString()
        var remaining = template[...]
        while let match = replacements.keys.compactMap({ key -> (key: String, index: String.Index)? in
            guard let index = remaining.range(of: key)?.lowerBound else {
                return nil
            }
            return (key, index)
        }).min(by: { $0.index < $1.index }) {
            let prefix = remaining[remaining.startIndex..<match.index]
            if !prefix.isEmpty {
                result.append(AttributedString(String(prefix)))
            }
            let (label, url) = replacements[match.key]!
            var link = AttributedString(label)
            link.link = url
            result.append(link)
            remaining = remaining[remaining.index(match.index, offsetBy: match.key.count)...]
        }
        if !remaining.isEmpty {
            result.append(AttributedString(String(remaining)))
        }
        return result
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
        case "pl":
            if n == 1 { return .one }
            let n10 = n % 10
            let n100 = n % 100
            if (2...4).contains(n10) && !(12...14).contains(n100) { return .few }
            return .many
        case "uk":
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
