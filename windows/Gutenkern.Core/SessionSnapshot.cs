namespace Gutenkern;

public sealed class SessionSnapshot
{
    public static SessionSnapshot Empty { get; } = new();

    public string Field1 { get; init; } = "";
    public string Field2 { get; init; } = "";
    public IReadOnlyList<string> Groups { get; init; } = [];
    public IReadOnlyList<string> CompletedRecipes { get; init; } = [];
    public string Mode { get; init; } = "simple";
    public string Format { get; init; } = "fontlab";

    public HashSet<string> CompletedRecipeSet => CompletedRecipes.ToHashSet();

    public OutputFormat OutputFormatValue => Format switch
    {
        "glyphs" => OutputFormat.Glyphs,
        _ => OutputFormat.FontLab
    };

    public static SessionSnapshot From(
        string field1,
        IEnumerable<string> completedRecipes,
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
            snapshot.OutputFormatValue);
    }
}
