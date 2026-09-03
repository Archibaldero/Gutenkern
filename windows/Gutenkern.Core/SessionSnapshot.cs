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

    public HashSet<KerningGroup> SelectedGroups
    {
        get
        {
            var selected = new HashSet<KerningGroup>();
            foreach (var code in Groups)
            {
                if (KerningPlan.TryParse(code, out var group))
                {
                    selected.Add(group);
                }
            }

            return selected;
        }
    }

    public HashSet<string> CompletedRecipeSet => CompletedRecipes.ToHashSet();

    public PairMode PairModeValue => Mode == "mirror" ? PairMode.Mirror : PairMode.Simple;

    public OutputFormat OutputFormatValue => Format switch
    {
        "glyphs" => OutputFormat.Glyphs,
        _ => OutputFormat.FontLab
    };

    public static SessionSnapshot From(
        string field1,
        string field2,
        IEnumerable<KerningGroup> selectedGroups,
        IEnumerable<string> completedRecipes,
        PairMode mode,
        OutputFormat format)
    {
        var selected = selectedGroups as HashSet<KerningGroup> ?? selectedGroups.ToHashSet();
        var groupCodes = Enum.GetValues<KerningGroup>()
            .Where(selected.Contains)
            .Select(KerningPlan.Code)
            .ToList();
        return new SessionSnapshot
        {
            Field1 = field1,
            Field2 = field2,
            Groups = groupCodes,
            CompletedRecipes = completedRecipes
                .Where(recipe => recipe.Length > 0)
                .Distinct()
                .OrderBy(recipe => recipe, StringComparer.Ordinal)
                .ToList(),
            Mode = mode == PairMode.Mirror ? "mirror" : "simple",
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
            snapshot.Field2 ?? "",
            snapshot.SelectedGroups,
            snapshot.CompletedRecipes ?? [],
            snapshot.PairModeValue,
            snapshot.OutputFormatValue);
    }
}
