using System.Globalization;
using System.IO;
using System.Text.Json;

namespace Gutenkern;

internal readonly record struct AppLanguage(string Code, string NativeName);

internal static class L10n
{
    public static readonly AppLanguage[] Languages =
    [
        new("en", "English"),
        new("de", "Deutsch"),
        new("fr", "Français"),
        new("pl", "Polski"),
        new("cs", "Čeština"),
        new("es", "Español"),
        new("sv", "Svenska"),
        new("it", "Italiano"),
        new("uk", "Українська")
    ];

    private static readonly HashSet<string> Supported = ["en", "de", "fr", "pl", "cs", "es", "sv", "it", "uk"];
    private static readonly Dictionary<string, Dictionary<string, string>> Catalog = LoadCatalog();
    private static Dictionary<string, string> Table = [];
    private static string Language = "en";

    static L10n()
    {
        AppSettings.Load();
        ApplyPreference(AppSettings.Language);
    }

    public static string FieldWhat => T("fieldWhat");
    public static string FieldWith => T("fieldWith");
    public static string Type => T("type");
    public static string TypeSimple => T("typeSimple");
    public static string TypeMirror => T("typeMirror");
    public static string Format => T("format");
    public static string FormatFontLab => T("formatFontLab");
    public static string FormatGlyphs => T("formatGlyphs");
    public static string Result => T("result");
    public static string Copy => T("copy");
    public static string Copied => T("copied");
    public static string File => T("file");
    public static string Save => T("save");
    public static string SaveEllipsis => T("saveEllipsis");
    public static string SaveFailed => T("saveFailed");
    public static string TextDocument => T("textDocument");
    public static string AllFiles => T("allFiles");
    public static string Settings => T("settings");
    public static string LanguageLabel => T("language");
    public static string LanguageSystem => T("languageSystem");
    public static string Groups => T("groups");
    public static string Plan => T("plan");
    public static string Help => T("help");
    public static string About => T("about");
    public static string AboutBody => T("aboutBody");
    public static string AboutContact => T("aboutContact");
    public static string AboutCopyright => T("aboutCopyright");
    public const string AuthorEmail = "armos1999@gmail.com";
    public const string AuthorWebsite = "arsenmosiichuk.in.ua";

    public static string AboutVersion(string version) => T("aboutVersion").Replace("{version}", version);

    public static string GroupLabel(KerningGroup group)
    {
        var name = group switch
        {
            KerningGroup.Capitals => T("groupCapitals"),
            KerningGroup.SmallCaps => T("groupSmallCaps"),
            KerningGroup.Lowercase => T("groupLowercase"),
            KerningGroup.Punctuation => T("groupPunctuation"),
            KerningGroup.NonAlphabetic => T("groupNonAlphabetic"),
            KerningGroup.LiningFigures => T("groupLiningFigures"),
            KerningGroup.OldstyleFigures => T("groupOldstyleFigures"),
            _ => throw new ArgumentOutOfRangeException(nameof(group), group, null)
        };
        return $"{name} ({KerningPlan.Code(group)})";
    }

    public static void ApplyPreference(string preference)
    {
        Language = Resolve(preference);
        Table = Merge(Language);
    }

    private static string T(string key) => Table.TryGetValue(key, out var value) ? value : key;

    private static string Resolve(string preference)
    {
        if (preference != AppSettings.SystemLanguage && Supported.Contains(preference))
        {
            return preference;
        }

        var culture = CultureInfo.CurrentUICulture;
        while (!string.IsNullOrEmpty(culture.Name) && !culture.Equals(CultureInfo.InvariantCulture))
        {
            var code = culture.TwoLetterISOLanguageName;
            if (Supported.Contains(code))
            {
                return code;
            }

            culture = culture.Parent;
        }

        return "en";
    }

    private static Dictionary<string, string> Merge(string language)
    {
        var merged = new Dictionary<string, string>();
        if (Catalog.TryGetValue("en", out var english) && english is not null)
        {
            foreach (var pair in english)
            {
                merged[pair.Key] = pair.Value;
            }
        }

        if (language != "en" && Catalog.TryGetValue(language, out var overlay) && overlay is not null)
        {
            foreach (var pair in overlay)
            {
                merged[pair.Key] = pair.Value;
            }
        }

        return merged;
    }

    private static Dictionary<string, Dictionary<string, string>> LoadCatalog()
    {
        try
        {
            var path = CatalogPath();
            if (path is null)
            {
                return [];
            }

            return JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(
                File.ReadAllText(path)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private static string? CatalogPath()
    {
        var nextToExe = Path.Combine(AppContext.BaseDirectory, "l10n.json");
        if (File.Exists(nextToExe))
        {
            return nextToExe;
        }

        var fromSource = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "core", "l10n.json"));
        return File.Exists(fromSource) ? fromSource : null;
    }

    private enum PluralCategory
    {
        One,
        Few,
        Many,
        Other
    }

    public static string PairCount(int count)
    {
        var key = Plural(count) switch
        {
            PluralCategory.One => "pairOne",
            PluralCategory.Few => "pairFew",
            PluralCategory.Many => "pairMany",
            _ => "pairOther"
        };
        return T(key).Replace("{count}", count.ToString(CultureInfo.CurrentCulture));
    }

    private static PluralCategory Plural(int count)
    {
        var n = Math.Abs(count);
        switch (Language)
        {
            case "pl":
                if (n == 1)
                {
                    return PluralCategory.One;
                }

                if (n % 10 is >= 2 and <= 4 && n % 100 is not (>= 12 and <= 14))
                {
                    return PluralCategory.Few;
                }

                return PluralCategory.Many;
            case "uk":
                var n10 = n % 10;
                var n100 = n % 100;
                if (n10 == 1 && n100 != 11)
                {
                    return PluralCategory.One;
                }

                if (n10 is >= 2 and <= 4 && n100 is not (>= 12 and <= 14))
                {
                    return PluralCategory.Few;
                }

                return PluralCategory.Many;
            case "cs":
                if (n == 1)
                {
                    return PluralCategory.One;
                }

                return n is >= 2 and <= 4 ? PluralCategory.Few : PluralCategory.Other;
            case "fr":
                return n <= 1 ? PluralCategory.One : PluralCategory.Other;
            default:
                return n == 1 ? PluralCategory.One : PluralCategory.Other;
        }
    }
}
