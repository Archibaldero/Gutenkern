namespace Gutenkern;

public enum KerningGroup
{
    Capitals,
    SmallCaps,
    Lowercase,
    Punctuation,
    NonAlphabetic,
    LiningFigures,
    OldstyleFigures
}

public static class KerningPlan
{
    public static string Code(KerningGroup group) => group switch
    {
        KerningGroup.Capitals => "A",
        KerningGroup.SmallCaps => "A.sc",
        KerningGroup.Lowercase => "a",
        KerningGroup.Punctuation => "-",
        KerningGroup.NonAlphabetic => "@",
        KerningGroup.LiningFigures => "1p",
        KerningGroup.OldstyleFigures => "1o",
        _ => throw new ArgumentOutOfRangeException(nameof(group), group, null)
    };

    public static bool TryParse(string code, out KerningGroup group)
    {
        switch (code)
        {
            case "A":
                group = KerningGroup.Capitals;
                return true;
            case "A.sc":
                group = KerningGroup.SmallCaps;
                return true;
            case "a":
                group = KerningGroup.Lowercase;
                return true;
            case "-":
                group = KerningGroup.Punctuation;
                return true;
            case "@":
                group = KerningGroup.NonAlphabetic;
                return true;
            case "1p":
                group = KerningGroup.LiningFigures;
                return true;
            case "1o":
                group = KerningGroup.OldstyleFigures;
                return true;
            default:
                group = default;
                return false;
        }
    }

    public static KerningGroup Parse(string code)
    {
        if (TryParse(code, out var group))
        {
            return group;
        }

        throw new ArgumentOutOfRangeException(nameof(code), code, null);
    }

    public static string Text(IEnumerable<KerningGroup> selected) =>
        string.Join("\n", Rows(selected).Select(row => string.Join(" ", row)));

    public static List<List<string>> Rows(IEnumerable<KerningGroup> selected)
    {
        var set = selected as HashSet<KerningGroup> ?? selected.ToHashSet();
        var result = new List<List<string>>();
        KerningGroup? currentBlock = null;
        var currentItems = new List<string>();
        foreach (var recipe in Recipes)
        {
            if (!set.Contains(recipe.Left) || !set.Contains(recipe.Right))
            {
                continue;
            }

            if (currentBlock != recipe.Left)
            {
                if (currentItems.Count > 0)
                {
                    result.Add(currentItems);
                    currentItems = [];
                }

                currentBlock = recipe.Left;
            }

            currentItems.Add(recipe.Line);
        }

        if (currentItems.Count > 0)
        {
            result.Add(currentItems);
        }

        return result;
    }

    public readonly record struct Recipe(KerningGroup Left, KerningGroup Right, PairMode Mode)
    {
        public string Line => Mode == PairMode.Simple
            ? $"{Code(Left)}/{Code(Right)}"
            : $"{Code(Left)}/{Code(Right)}/{Code(Left)}";
    }

    public static IReadOnlyList<Recipe> Recipes { get; } =
    [
        new(KerningGroup.Capitals, KerningGroup.Capitals, PairMode.Mirror),
        new(KerningGroup.Capitals, KerningGroup.SmallCaps, PairMode.Simple),
        new(KerningGroup.Capitals, KerningGroup.Lowercase, PairMode.Simple),
        new(KerningGroup.Capitals, KerningGroup.Punctuation, PairMode.Mirror),
        new(KerningGroup.Capitals, KerningGroup.NonAlphabetic, PairMode.Mirror),
        new(KerningGroup.Capitals, KerningGroup.LiningFigures, PairMode.Mirror),
        new(KerningGroup.Capitals, KerningGroup.OldstyleFigures, PairMode.Mirror),

        new(KerningGroup.SmallCaps, KerningGroup.SmallCaps, PairMode.Mirror),
        new(KerningGroup.SmallCaps, KerningGroup.Punctuation, PairMode.Mirror),

        new(KerningGroup.Lowercase, KerningGroup.Lowercase, PairMode.Mirror),
        new(KerningGroup.Lowercase, KerningGroup.Punctuation, PairMode.Mirror),
        new(KerningGroup.Lowercase, KerningGroup.NonAlphabetic, PairMode.Mirror),
        new(KerningGroup.Lowercase, KerningGroup.LiningFigures, PairMode.Mirror),
        new(KerningGroup.Lowercase, KerningGroup.OldstyleFigures, PairMode.Mirror),

        new(KerningGroup.NonAlphabetic, KerningGroup.NonAlphabetic, PairMode.Mirror),
        new(KerningGroup.NonAlphabetic, KerningGroup.LiningFigures, PairMode.Mirror),
        new(KerningGroup.NonAlphabetic, KerningGroup.OldstyleFigures, PairMode.Mirror),

        new(KerningGroup.LiningFigures, KerningGroup.LiningFigures, PairMode.Mirror),
        new(KerningGroup.LiningFigures, KerningGroup.Punctuation, PairMode.Mirror),

        new(KerningGroup.OldstyleFigures, KerningGroup.OldstyleFigures, PairMode.Mirror),
        new(KerningGroup.OldstyleFigures, KerningGroup.Punctuation, PairMode.Mirror)
    ];
}
