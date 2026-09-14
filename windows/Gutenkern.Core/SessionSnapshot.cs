namespace Gutenkern;

public sealed class SessionSnapshot
{
    public static SessionSnapshot Empty { get; } = new();
    public const string DefaultGlyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    public string Field1 { get; init; } = "";
    public string Field2 { get; init; } = "";
    public IReadOnlyList<string> Groups { get; init; } = [];
    public IReadOnlyList<string> CompletedRecipes { get; init; } = [];
    public IReadOnlyList<string> CompletedBlocks { get; init; } = [];
    public string Mode { get; init; } = "simple";
    public string Format { get; init; } = "fontlab";

    public HashSet<string> CompletedRecipeSet => CompletedRecipes.ToHashSet();
    public HashSet<string> CompletedBlockSet => CompletedBlocks.ToHashSet();

    public OutputFormat OutputFormatValue => Format switch
    {
        "glyphs" => OutputFormat.Glyphs,
        _ => OutputFormat.FontLab
    };

    public static SessionSnapshot From(
        string field1,
        IEnumerable<string> completedRecipes,
        IEnumerable<string> completedBlocks,
        OutputFormat format)
    {
        return new SessionSnapshot
        {
            Field1 = field1,
            Field2 = "",
            Groups = [],
            CompletedRecipes = completedRecipes
                .Where(recipe => recipe.Length > 0)
                .Distinct()
                .OrderBy(recipe => recipe, StringComparer.Ordinal)
                .ToList(),
            CompletedBlocks = KerningCompletion.ExpandPairKeys(completedBlocks)
                .OrderBy(block => block, StringComparer.Ordinal)
                .ToList(),
            Mode = "simple",
            Format = format switch
            {
                OutputFormat.Glyphs => "glyphs",
                _ => "fontlab"
            }
        };
    }

    public static SessionSnapshot Sanitize(SessionSnapshot? snapshot)
    {
        if (snapshot is null)
        {
            return Empty;
        }

        return From(
            snapshot.Field1 ?? "",
            snapshot.CompletedRecipes ?? [],
            snapshot.CompletedBlocks ?? [],
            snapshot.OutputFormatValue);
    }
}
