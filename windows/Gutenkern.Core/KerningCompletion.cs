namespace Gutenkern;

public sealed record PairLine(string Key, string Display);

public sealed class RecipeSection
{
    public string Recipe { get; }
    public IReadOnlyList<string> Groups { get; }
    public IReadOnlyList<IReadOnlyList<PairLine>> PairGroups { get; }

    public RecipeSection(string recipe, IReadOnlyList<string> groups)
        : this(recipe, groups.Select(ParseBlock).ToList())
    {
    }

    public RecipeSection(string recipe, IReadOnlyList<IReadOnlyList<PairLine>> pairGroups)
    {
        Recipe = recipe;
        PairGroups = pairGroups;
        Groups = pairGroups
            .Select(group => string.Join("\n", group.Select(pair => pair.Display)))
            .ToList();
    }

    private static IReadOnlyList<PairLine> ParseBlock(string block) =>
        KerningCompletion.PairKeys(block).Select(line => new PairLine(line, line)).ToList();
}

public sealed class KerningCompletion
{
    public HashSet<string> Recipes { get; }
    public HashSet<string> Blocks { get; }

    public KerningCompletion(IEnumerable<string> recipes, IEnumerable<string> blocks)
    {
        Recipes = [.. recipes];
        Blocks = ExpandPairKeys(blocks);
    }

    public bool IsRecipeDone(string recipe, IReadOnlyList<RecipeSection> sections) =>
        AllGroupsDone(recipe, sections);

    public bool IsBlockDone(string block) => IsBlockDone(PairKeys(block));

    public bool IsBlockDone(IReadOnlyList<string> keys) =>
        keys.Count > 0 && keys.All(Blocks.Contains);

    public void ToggleRecipe(string recipe, IReadOnlyList<RecipeSection> sections)
    {
        var keys = PairKeys(recipe, sections);
        if (IsRecipeDone(recipe, sections))
        {
            Recipes.Remove(recipe);
            foreach (var key in keys)
            {
                Blocks.Remove(key);
            }
        }
        else
        {
            Recipes.Add(recipe);
            foreach (var key in keys)
            {
                Blocks.Add(key);
            }
        }

        SyncRecipes(sections);
    }

    public void ToggleBlock(string block, IReadOnlyList<RecipeSection> sections) =>
        ToggleKeys(PairKeys(block), sections);

    public void ToggleKeys(IReadOnlyList<string> keys, IReadOnlyList<RecipeSection> sections)
    {
        if (IsBlockDone(keys))
        {
            foreach (var key in keys)
            {
                Blocks.Remove(key);
            }
        }
        else
        {
            foreach (var key in keys)
            {
                Blocks.Add(key);
            }
        }

        SyncRecipes(sections);
    }

    public void ApplyDone(IEnumerable<string> done, IReadOnlyList<RecipeSection> sections)
    {
        Blocks.Clear();
        foreach (var key in ExpandPairKeys(done))
        {
            Blocks.Add(key);
        }

        SyncRecipes(sections);
    }

    public void Sync(IReadOnlyList<RecipeSection> sections)
    {
        var known = AllPairKeys(sections);
        Blocks.RemoveWhere(key => !known.Contains(key));
        foreach (var section in sections)
        {
            if (section.PairGroups.Count == 0)
            {
                continue;
            }

            var keys = PairKeys(section);
            var marked = keys.Count(Blocks.Contains);
            if (Recipes.Contains(section.Recipe) && marked == 0)
            {
                foreach (var key in keys)
                {
                    Blocks.Add(key);
                }
            }
        }

        SyncRecipes(sections);
    }

    public void SyncRecipes(IReadOnlyList<RecipeSection> sections)
    {
        foreach (var section in sections)
        {
            if (section.PairGroups.Count == 0)
            {
                continue;
            }

            if (PairKeys(section).All(Blocks.Contains))
            {
                Recipes.Add(section.Recipe);
            }
            else
            {
                Recipes.Remove(section.Recipe);
            }
        }
    }

    public static List<string> PairKeys(string block) =>
        block.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .Select(CanonicalizePairKey)
            .Where(key => key.Length > 0)
            .ToList();

    public static List<string> PairKeys(RecipeSection section) =>
        section.PairGroups.SelectMany(group => group.Select(pair => pair.Key)).ToList();

    public static List<string> PairKeys(string recipe, IReadOnlyList<RecipeSection> sections)
    {
        foreach (var section in sections)
        {
            if (section.Recipe == recipe)
            {
                return PairKeys(section);
            }
        }

        return [];
    }

    public static HashSet<string> AllPairKeys(IReadOnlyList<RecipeSection> sections) =>
        sections.SelectMany(PairKeys).ToHashSet();

    public static HashSet<string> ExpandPairKeys(IEnumerable<string> blocks) =>
        blocks.SelectMany(PairKeys).ToHashSet();

    public static string CanonicalizePairKey(string key) =>
        key.Length == 0 || key.StartsWith('/') ? key : "/" + key;

    private bool AllGroupsDone(string recipe, IReadOnlyList<RecipeSection> sections)
    {
        var keys = PairKeys(recipe, sections);
        return keys.Count > 0 && keys.All(Blocks.Contains);
    }
}
