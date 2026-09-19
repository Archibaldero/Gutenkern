namespace Gutenkern;

public readonly record struct ParsedToken(Glyph Glyph, int Start, int Length);

public sealed class ClassificationResult
{
    public IReadOnlyList<KerningGroup> Groups { get; }
    public IReadOnlyDictionary<KerningGroup, IReadOnlyList<Glyph>> Glyphs { get; }
    public IReadOnlyList<ParsedToken> Unknown { get; }

    internal ClassificationResult(
        IReadOnlyList<KerningGroup> groups,
        IReadOnlyDictionary<KerningGroup, IReadOnlyList<Glyph>> glyphs,
        IReadOnlyList<ParsedToken> unknown)
    {
        Groups = groups;
        Glyphs = glyphs;
        Unknown = unknown;
    }

    public bool TryGet(KerningGroup group, out IReadOnlyList<Glyph> glyphs) =>
        Glyphs.TryGetValue(group, out glyphs!);
}

public static class GlyphClassifier
{
    private enum Kind
    {
        Unknown,
        Capital,
        Lowercase,
        SmallCaps,
        Punctuation,
        NonAlphabetic,
        LiningPlain,
        LiningPnum,
        OldstyleOnum,
        OldstyleProportional
    }

    public static ClassificationResult Classify(string input)
    {
        var tokens = KerningGenerator.ParseTokens(input);
        var unknown = new List<ParsedToken>();
        var tagged = new List<(Glyph Glyph, Kind Kind)>();

        foreach (var token in tokens)
        {
            var kind = ClassifyToken(token.Glyph);
            if (kind == Kind.Unknown)
            {
                unknown.Add(token);
                continue;
            }

            tagged.Add((token.Glyph, kind));
        }

        var hasPnum = tagged.Any(item => item.Kind == Kind.LiningPnum);
        var hasProportionalOldstyle = tagged.Any(item => item.Kind == Kind.OldstyleProportional);
        var buckets = Enum.GetValues<KerningGroup>().ToDictionary(
            group => group,
            _ => new List<Glyph>());

        foreach (var (glyph, kind) in tagged)
        {
            var group = kind switch
            {
                Kind.Capital => KerningGroup.Capitals,
                Kind.Lowercase => KerningGroup.Lowercase,
                Kind.SmallCaps => KerningGroup.SmallCaps,
                Kind.Punctuation => KerningGroup.Punctuation,
                Kind.NonAlphabetic => KerningGroup.NonAlphabetic,
                Kind.LiningPlain when hasPnum => (KerningGroup?)null,
                Kind.LiningPlain => KerningGroup.LiningFigures,
                Kind.LiningPnum => KerningGroup.LiningFigures,
                Kind.OldstyleOnum when hasProportionalOldstyle => (KerningGroup?)null,
                Kind.OldstyleOnum => KerningGroup.OldstyleFigures,
                Kind.OldstyleProportional => KerningGroup.OldstyleFigures,
                _ => null
            };
            if (group is { } resolved)
            {
                buckets[resolved].Add(glyph);
            }
        }

        var present = Enum.GetValues<KerningGroup>()
            .Where(group => buckets[group].Count > 0)
            .ToList();
        var glyphs = present.ToDictionary(
            group => group,
            group => (IReadOnlyList<Glyph>)buckets[group]);
        return new ClassificationResult(present, glyphs, unknown);
    }

    private static Kind ClassifyToken(Glyph glyph)
    {
        switch (glyph)
        {
            case CharacterGlyph character:
                if (GlyphDictionary.TryClassByChar(character.Value, out var byChar))
                {
                    return FromDictionary(byChar);
                }

                return GlyphDictionary.IsAsciiDigit(character.Value)
                    ? Kind.LiningPlain
                    : Kind.Unknown;
            case NameGlyph name:
                return ClassifyName(name.Value);
            default:
                return Kind.Unknown;
        }
    }

    private static Kind ClassifyName(string name)
    {
        var parts = name.Split('.', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0)
        {
            return Kind.Unknown;
        }

        var suffixes = parts.Skip(1).ToHashSet(StringComparer.Ordinal);
        if (suffixes.Overlaps(["sc", "smcp", "c2sc"]))
        {
            return Kind.SmallCaps;
        }

        var baseName = parts[0];
        var hasPnum = suffixes.Overlaps(["pnum", "lf"]);
        var hasOnum = suffixes.Overlaps(["onum", "tosf"]);
        var hasOsf = suffixes.Contains("osf");
        var hasTf = suffixes.Contains("tf");
        if (GlyphDictionary.IsDigitName(baseName) && (hasPnum || hasOnum || hasOsf || hasTf))
        {
            if (hasOsf || (hasPnum && hasOnum))
            {
                return Kind.OldstyleProportional;
            }

            if (hasOnum)
            {
                return Kind.OldstyleOnum;
            }

            if (hasPnum)
            {
                return Kind.LiningPnum;
            }

            return Kind.LiningPlain;
        }

        if (GlyphDictionary.TryClassByName(name, out var exact))
        {
            return FromDictionary(exact);
        }

        if (GlyphDictionary.TryClassByName(baseName, out var byBase))
        {
            return FromDictionary(byBase);
        }

        return Kind.Unknown;
    }

    private static Kind FromDictionary(string classification) => classification switch
    {
        "capital" => Kind.Capital,
        "lowercase" => Kind.Lowercase,
        "digit" => Kind.LiningPlain,
        "punctuation" => Kind.Punctuation,
        "nonalphabetic" => Kind.NonAlphabetic,
        _ => Kind.Unknown
    };
}
