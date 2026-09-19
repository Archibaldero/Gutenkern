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
                if (index + 1 < input.Length && input[index + 1] == '/')
                {
                    tokens.Add(new ParsedToken(new CharacterGlyph("/"), index, 2));
                    index += 2;
                    continue;
                }

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

    public static string Generate(ClassificationResult classified, OutputFormat format) =>
        string.Join("\n\n\n", GenerateSections(classified, format).Select(section => string.Join("\n\n", section)));

    public static List<List<string>> GenerateSections(ClassificationResult classified, OutputFormat format) =>
        GenerateRecipeSections(classified, format).Select(section => section.Groups.ToList()).ToList();

    public static List<RecipeSection> GenerateRecipeSections(ClassificationResult classified, OutputFormat format)
    {
        var sections = new List<RecipeSection>();
        foreach (var recipe in KerningPlan.Recipes)
        {
            if (!classified.TryGet(recipe.Left, out var left) ||
                !classified.TryGet(recipe.Right, out var right))
            {
                continue;
            }

            var pairGroups = GeneratePairGroups(
                left,
                right,
                recipe.Mode,
                format,
                KerningScriptFilter.IsLetterGroup(recipe.Left) && KerningScriptFilter.IsLetterGroup(recipe.Right));
            if (pairGroups.Count > 0)
            {
                sections.Add(new RecipeSection(recipe.Line, pairGroups));
            }
        }

        return sections;
    }

    public static string Generate(
        IReadOnlyList<Glyph> leftGlyphs,
        IReadOnlyList<Glyph> rightGlyphs,
        PairMode mode,
        OutputFormat format) =>
        string.Join("\n\n", GenerateGroups(leftGlyphs, rightGlyphs, mode, format));

    public static List<string> GenerateGroups(
        IReadOnlyList<Glyph> leftGlyphs,
        IReadOnlyList<Glyph> rightGlyphs,
        PairMode mode,
        OutputFormat format,
        bool letterLetterRecipe = false) =>
        GeneratePairGroups(leftGlyphs, rightGlyphs, mode, format, letterLetterRecipe)
            .Select(group => string.Join("\n", group.Select(pair => pair.Display)))
            .ToList();

    public static List<IReadOnlyList<PairLine>> GeneratePairGroups(
        IReadOnlyList<Glyph> leftGlyphs,
        IReadOnlyList<Glyph> rightGlyphs,
        PairMode mode,
        OutputFormat format,
        bool letterLetterRecipe = false)
    {
        if (leftGlyphs.Count == 0 || rightGlyphs.Count == 0)
        {
            return [];
        }

        var groups = new List<IReadOnlyList<PairLine>>(leftGlyphs.Count);
        foreach (var leftGlyph in leftGlyphs)
        {
            var groupLines = new List<PairLine>(rightGlyphs.Count);
            foreach (var rightGlyph in rightGlyphs)
            {
                if (!KerningScriptFilter.ShouldKern(leftGlyph, rightGlyph, letterLetterRecipe))
                {
                    continue;
                }

                var sequence = mode == PairMode.Simple
                    ? new[] { leftGlyph, rightGlyph }
                    : new[] { leftGlyph, rightGlyph, leftGlyph };
                groupLines.Add(new PairLine(
                    FormatGlyphs(sequence, OutputFormat.FontLab),
                    FormatGlyphs(sequence, format)));
            }

            if (groupLines.Count > 0)
            {
                groups.Add(groupLines);
            }
        }

        return groups;
    }

    public static string FormatGlyphs(IReadOnlyList<Glyph> glyphs, OutputFormat format)
    {
        switch (format)
        {
            case OutputFormat.FontLab:
                if (glyphs.Count == 0)
                {
                    return "";
                }

                return "/" + string.Join("/", glyphs.Select(PlainValue));
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
