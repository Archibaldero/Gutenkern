using System.Reflection;
using System.Text.Json;

namespace Gutenkern;

internal static class GlyphDictionary
{
    private static readonly Dictionary<string, string> Names;
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
        Names = payload.Names ?? [];
        Chars = payload.Chars ?? [];
    }

    public static bool TryClassByName(string name, out string classification) =>
        Names.TryGetValue(name, out classification!);

    public static bool TryClassByChar(string value, out string classification) =>
        Chars.TryGetValue(value, out classification!);

    public static bool IsDigitName(string name) =>
        (Names.TryGetValue(name, out var classification) && classification == "digit")
        || IsAsciiDigit(name);

    public static bool IsDigitChar(string value) =>
        (Chars.TryGetValue(value, out var classification) && classification == "digit")
        || IsAsciiDigit(value);

    public static bool IsAsciiDigit(string value) =>
        value.Length == 1 && value[0] is >= '0' and <= '9';

    private sealed class Payload
    {
        public Dictionary<string, string>? Names { get; set; }
        public Dictionary<string, string>? Chars { get; set; }
    }
}
