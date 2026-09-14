namespace Gutenkern;

internal enum GlyphScript
{
    Latin,
    Cyrillic,
    Greek,
    Unknown
}

internal static class KerningScriptFilter
{
    public static bool IsLetterGroup(KerningGroup group) =>
        group is KerningGroup.Capitals or KerningGroup.SmallCaps or KerningGroup.Lowercase;

    public static bool ShouldKern(Glyph left, Glyph right, bool letterLetterRecipe)
    {
        if (!letterLetterRecipe)
        {
            return true;
        }

        var leftScript = ScriptOf(left);
        var rightScript = ScriptOf(right);
        if (leftScript == GlyphScript.Unknown || rightScript == GlyphScript.Unknown)
        {
            return true;
        }

        return leftScript == rightScript;
    }

    public static int PairCount(IReadOnlyList<Glyph> left, IReadOnlyList<Glyph> right, bool letterLetterRecipe)
    {
        if (!letterLetterRecipe)
        {
            return left.Count * right.Count;
        }

        var total = 0;
        foreach (var leftGlyph in left)
        {
            foreach (var rightGlyph in right)
            {
                if (ShouldKern(leftGlyph, rightGlyph, true))
                {
                    total++;
                }
            }
        }

        return total;
    }

    public static GlyphScript FromUnicodeName(string unicodeName)
    {
        if (string.IsNullOrEmpty(unicodeName))
        {
            return GlyphScript.Unknown;
        }

        var first = unicodeName.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (first.Length == 0)
        {
            return GlyphScript.Unknown;
        }

        return first[0] switch
        {
            "LATIN" or "FEMININE" or "MASCULINE" => GlyphScript.Latin,
            "CYRILLIC" => GlyphScript.Cyrillic,
            "GREEK" => GlyphScript.Greek,
            _ => GlyphScript.Unknown
        };
    }

    public static GlyphScript FromCodePoint(int value)
    {
        if (value is >= 0x0370 and <= 0x03FF or >= 0x1F00 and <= 0x1FFF)
        {
            return GlyphScript.Greek;
        }

        if (value is >= 0x0400 and <= 0x052F or >= 0x2DE0 and <= 0x2DFF or >= 0xA640 and <= 0xA69F)
        {
            return GlyphScript.Cyrillic;
        }

        if (value is >= 0x0000 and <= 0x02AF
            or >= 0x1E00 and <= 0x1EFF
            or >= 0x2C60 and <= 0x2C7F
            or >= 0xA720 and <= 0xA7FF
            or >= 0xAB30 and <= 0xAB6F)
        {
            return GlyphScript.Latin;
        }

        return GlyphScript.Unknown;
    }

    private static GlyphScript ScriptOf(Glyph glyph) => glyph switch
    {
        CharacterGlyph character => GlyphDictionary.ScriptByChar(character.Value),
        NameGlyph name => GlyphDictionary.ScriptByName(name.Value),
        _ => GlyphScript.Unknown
    };
}
