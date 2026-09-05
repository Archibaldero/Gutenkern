using System.Globalization;

namespace Gutenkern;

public abstract record Glyph;

public sealed record CharacterGlyph(string Value) : Glyph;

public sealed record NameGlyph(string Value) : Glyph;

public enum PairMode
{
    Simple,
    Mirror
}

public enum OutputFormat
{
    FontLab,
    Glyphs
}

public static class KerningGenerator
{
    public static List<Glyph> Parse(string input) =>
        ParseTokens(input).Select(token => token.Glyph).ToList();

    public static List<ParsedToken> ParseTokens(string input)
    {
        var tokens = new List<ParsedToken>();
        var index = 0;

        while (index < input.Length)
        {
            var character = input[index];
            if (char.IsWhiteSpace(character))
            {
                index++;
                continue;
            }

            if (character == '/')
            {
                var slash = index;
                index++;
                var start = index;
                while (index < input.Length && input[index] != '/' && !char.IsWhiteSpace(input[index]))
                {
                    index++;
                }

                var name = input[start..index];
                if (name.Length > 0)
                {
                    tokens.Add(new ParsedToken(new NameGlyph(name), slash, index - slash));
                }

                continue;
            }

            var elementLength = StringInfo.GetNextTextElementLength(input, index);
            tokens.Add(new ParsedToken(
                new CharacterGlyph(input.Substring(index, elementLength)),
                index,
                elementLength));
            index += elementLength;
        }

        return tokens;
    }

    public static string Generate(string left, string right, PairMode mode, OutputFormat format) =>
        Generate(Parse(left), Parse(right), mode, format);

    public static string Generate(string input, OutputFormat format) =>
        Generate(GlyphClassifier.Classify(input), format);

    public static string Generate(ClassificationResult classified, OutputFormat format)
    {
        var sections = new List<string>();
        foreach (var recipe in KerningPlan.Recipes)
        {
            if (!classified.TryGet(recipe.Left, out var left) ||
                !classified.TryGet(recipe.Right, out var right))
            {
                continue;
            }

            var section = Generate(left, right, recipe.Mode, format);
            if (section.Length > 0)
            {
                sections.Add(section);
            }
        }

        return string.Join("\n\n\n", sections);
    }

    public static string Generate(
        IReadOnlyList<Glyph> leftGlyphs,
        IReadOnlyList<Glyph> rightGlyphs,
        PairMode mode,
        OutputFormat format)
    {
        if (leftGlyphs.Count == 0 || rightGlyphs.Count == 0)
        {
            return string.Empty;
        }

        var groups = new List<string>(leftGlyphs.Count);
        foreach (var leftGlyph in leftGlyphs)
        {
            var groupLines = new List<string>(rightGlyphs.Count);
            foreach (var rightGlyph in rightGlyphs)
            {
                var sequence = mode == PairMode.Simple
                    ? new[] { leftGlyph, rightGlyph }
                    : new[] { leftGlyph, rightGlyph, leftGlyph };
                groupLines.Add(FormatGlyphs(sequence, format));
            }

            groups.Add(string.Join("\n", groupLines));
        }

        return string.Join("\n\n", groups);
    }

    public static int PairCount(string left, string right)
    {
        var leftCount = Parse(left).Count;
        var rightCount = Parse(right).Count;
        if (leftCount == 0 || rightCount == 0)
        {
            return 0;
        }

        return leftCount * rightCount;
    }

    public static int PairCount(string input) => PairCount(GlyphClassifier.Classify(input));

    public static int PairCount(ClassificationResult classified)
    {
        var total = 0;
        foreach (var recipe in KerningPlan.Recipes)
        {
            if (!classified.TryGet(recipe.Left, out var left) ||
                !classified.TryGet(recipe.Right, out var right))
            {
                continue;
            }

            total += left.Count * right.Count;
        }

        return total;
    }

    public static string FormatGlyphs(IReadOnlyList<Glyph> glyphs, OutputFormat format)
    {
        switch (format)
        {
            case OutputFormat.FontLab:
                return string.Join("/", glyphs.Select(PlainValue));
            case OutputFormat.Glyphs:
                var result = new System.Text.StringBuilder();
                var previousWasName = false;
                foreach (var glyph in glyphs)
                {
                    switch (glyph)
                    {
                        case CharacterGlyph character:
                            if (previousWasName)
                            {
                                result.Append(' ');
                            }

                            result.Append(character.Value);
                            previousWasName = false;
                            break;
                        case NameGlyph name:
                            result.Append('/');
                            result.Append(name.Value);
                            previousWasName = true;
                            break;
                    }
                }

                return result.ToString();
            default:
                throw new ArgumentOutOfRangeException(nameof(format), format, null);
        }
    }

    private static string PlainValue(Glyph glyph) => glyph switch
    {
        CharacterGlyph character => character.Value,
        NameGlyph name => name.Value,
        _ => throw new ArgumentOutOfRangeException(nameof(glyph), glyph, null)
    };
}
