using System.Globalization;
using System.IO;
using System.Text.Json;

namespace Gutenkern;

internal readonly record struct AppLanguage(string Code, string NativeName);

internal readonly record struct CreditPart(string Text, Uri? Link);

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
    public static string FieldWhatHint => T("fieldWhatHint");
    public static string GroupCopied => T("groupCopied");
    public static string ClickHint => T("clickHint").Replace("{modifier}", "Ctrl");
    public static string NewUnkernedPairs => T("newUnkernedPairs");
    public static string Format => T("format");
    public static string FormatFontLab => T("formatFontLab");
    public static string FormatGlyphs => T("formatGlyphs");
    public static string Result => T("result");
    public static string ResultAs => T("resultAs");
    public static string ResultLayoutRow => T("resultLayoutRow");
    public static string ResultLayoutColumn => T("resultLayoutColumn");
    public static string Copy => T("copy");
    public static string Copied => T("copied");
    public static string CopyAll => T("copyAll");
    public static string File => T("file");
    public static string Save => T("save");
    public static string SaveEllipsis => T("saveEllipsis");
    public static string SaveAndOpenEllipsis => T("saveAndOpenEllipsis");
    public static string SaveAsFile => T("saveAsFile");
    public static string SaveFailed => T("saveFailed");
    public static string StrikeThrough => T("strikeThrough");
    public static string ClearStrike => T("clearStrike");
    public static string ResultPlaceholder => T("resultPlaceholder");
    public static string ChooseFormat => T("chooseFormat");
    public static string ResetProgress => T("resetProgress");
    public static string Undo => T("undo");
    public static string Redo => T("redo");
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
    public const string VladWebsite = "zahrevsky.com";
    public const string OleksiiWebsite = "oleksii.shmalko.com";
    public const string SourceWebsite = "http://www.junikstudio.com/kernings/";
    public static Uri SourceWebsiteUrl { get; } = new(SourceWebsite);

    public static string AboutVersion(string version) => T("aboutVersion").Replace("{version}", version);

    public static List<CreditPart> AboutBodyParts() =>
        TemplateParts(AboutBody, new Dictionary<string, (string Label, Uri Url)>
        {
            [SourceWebsite] = (SourceWebsite, SourceWebsiteUrl)
        });

    public static List<CreditPart> AboutCreditsParts() =>
        TemplateParts(AboutCopyright, new Dictionary<string, (string Label, Uri Url)>
        {
            ["{arsenSite}"] = (AuthorWebsite, new Uri("https://" + AuthorWebsite)),
            ["{vladSite}"] = (VladWebsite, new Uri("https://" + VladWebsite)),
            ["{oleksiiSite}"] = (OleksiiWebsite, new Uri("https://" + OleksiiWebsite))
        });

    private static List<CreditPart> TemplateParts(
        string template,
        Dictionary<string, (string Label, Uri Url)> replacements)
    {
        var parts = new List<CreditPart>();
        var remaining = template;
        while (true)
        {
            string? nextKey = null;
            var nextIndex = -1;
            foreach (var key in replacements.Keys)
            {
                var index = remaining.IndexOf(key, StringComparison.Ordinal);
                if (index >= 0 && (nextIndex < 0 || index < nextIndex))
                {
                    nextKey = key;
                    nextIndex = index;
                }
            }

            if (nextKey is null)
            {
                break;
            }

            if (nextIndex > 0)
            {
                parts.Add(new CreditPart(remaining[..nextIndex], null));
            }

            var (label, url) = replacements[nextKey];
            parts.Add(new CreditPart(label, url));
            remaining = remaining[(nextIndex + nextKey.Length)..];
        }

        if (remaining.Length > 0)
        {
            parts.Add(new CreditPart(remaining, null));
        }

        return parts;
    }

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
        return name;
    }

    public static string GroupSidebarLabel(KerningGroup group, int done, int total)
    {
        var label = GroupLabel(group);
        if (total <= 0)
        {
            return label;
        }

        label += $" ⋅ {GroupedCount(done)}/{GroupedCount(total)}";
        if (done == total)
        {
            label += " ✓";
        }

        return label;
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
                System.IO.File.ReadAllText(path)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private static string? CatalogPath()
    {
        var nextToExe = Path.Combine(AppContext.BaseDirectory, "l10n.json");
        if (System.IO.File.Exists(nextToExe))
        {
            return nextToExe;
        }

        var fromSource = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "core", "l10n.json"));
        return System.IO.File.Exists(fromSource) ? fromSource : null;
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
        return T(key).Replace("{count}", GroupedCount(count));
    }

    public static string PairPercent(int percent) =>
        T("pairPercent").Replace("{percent}", percent.ToString(CultureInfo.InvariantCulture));

    public static string CopiedPairs(string pairs) =>
        T("copiedPairs").Replace("{pairs}", pairs);

    public static string PairProgress(int done, int total)
    {
        var progress = $"{GroupedCount(done)}/{GroupedCount(total)}";
        return PairCount(total).Replace(GroupedCount(total), progress);
    }

    public static int PairProgressPercent(int done, int total) =>
        total <= 0 ? 0 : (int)Math.Round(100.0 * done / total);

    public static string GroupedCount(int count)
    {
        var sign = count < 0 ? "-" : "";
        var digits = Math.Abs(count).ToString(CultureInfo.InvariantCulture);
        var grouped = new System.Text.StringBuilder();
        for (var index = 0; index < digits.Length; index++)
        {
            var fromEnd = digits.Length - index;
            if (index > 0 && fromEnd % 3 == 0)
            {
                grouped.Append('\u202F');
            }

            grouped.Append(digits[index]);
        }

        return sign + grouped.ToString();
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
