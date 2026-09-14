using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Gutenkern;

internal static class GlyphDictionary
{
    private static readonly Dictionary<string, NameEntry> Names;
    private static readonly Dictionary<string, string> Chars;

    static GlyphDictionary()
    {
        using var stream = Assembly.GetExecutingAssembly()
            .GetManifestResourceStream("Gutenkern.glyph-dictionary.json")
            ?? throw new InvalidOperationException("glyph-dictionary.json is missing");
        using var reader = new StreamReader(stream);
        var payload = JsonSerializer.Deserialize<Payload>(
            reader.ReadToEnd(),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("glyph-dictionary.json is empty");
        Names = (payload.Names ?? []).ToDictionary(
            pair => pair.Key,
            pair => pair.Value,
            StringComparer.Ordinal);
        Chars = payload.Chars ?? [];
    }

    public static bool TryClassByName(string name, out string classification)
    {
        if (Names.TryGetValue(name, out var entry))
        {
            classification = entry.Class;
            return true;
        }

        classification = "";
        return false;
    }

    public static bool TryClassByChar(string value, out string classification) =>
        Chars.TryGetValue(value, out classification!);

    public static bool IsDigitName(string name) =>
        (Names.TryGetValue(name, out var entry) && entry.Class == "digit")
        || IsAsciiDigit(name);

    public static GlyphScript ScriptByName(string name)
    {
        if (Names.TryGetValue(name, out var entry))
        {
            return KerningScriptFilter.FromUnicodeName(entry.UnicodeName);
        }

        var dot = name.IndexOf('.');
        if (dot > 0 && Names.TryGetValue(name[..dot], out entry))
        {
            return KerningScriptFilter.FromUnicodeName(entry.UnicodeName);
        }

        return GlyphScript.Unknown;
    }

    public static GlyphScript ScriptByChar(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return GlyphScript.Unknown;
        }

        var codePoint = char.ConvertToUtf32(value, 0);
        return KerningScriptFilter.FromCodePoint(codePoint);
    }

    public static bool IsDigitChar(string value) =>
        (Chars.TryGetValue(value, out var classification) && classification == "digit")
        || IsAsciiDigit(value);

    public static bool IsAsciiDigit(string value) =>
        value.Length == 1 && value[0] is >= '0' and <= '9';

    private sealed class Payload
    {
        public Dictionary<string, NameEntry>? Names { get; set; }
        public Dictionary<string, string>? Chars { get; set; }
    }

    private sealed class NameEntry
    {
        [JsonPropertyName("class")]
        public string Class { get; set; } = "";

        public string UnicodeName { get; set; } = "";
    }
}
