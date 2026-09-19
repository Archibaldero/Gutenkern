namespace Gutenkern;

public enum ResultLayoutMode
{
    Row,
    Column
}

public sealed class ResultGroup
{
    public string GroupId { get; }
    public KerningGroup Category { get; }
    public IReadOnlyList<PairLine> Pairs { get; }
    public IReadOnlyList<string> Keys { get; }

    public string CopyText => string.Join("  ", Pairs.Select(pair => pair.Display));

    public ResultGroup(string groupId, KerningGroup category, IReadOnlyList<PairLine> pairs)
    {
        GroupId = groupId;
        Category = category;
        Pairs = pairs;
        Keys = pairs.Select(pair => pair.Key).ToList();
    }
}

public sealed class ResultCategory
{
    public KerningGroup Group { get; }
    public IReadOnlyList<ResultGroup> Blocks { get; }

    public ResultCategory(KerningGroup group, IReadOnlyList<ResultGroup> blocks)
    {
        Group = group;
        Blocks = blocks;
    }
}

public sealed class ResultToken
{
    public string Key { get; }
    public string Display { get; }
    public string GroupId { get; }
    public KerningGroup Category { get; }
    public int Utf16Start { get; }
    public int Utf16Length { get; }
    public int Utf16End => Utf16Start + Utf16Length;

    public ResultToken(
        string key,
        string display,
        string groupId,
        KerningGroup category,
        int utf16Start,
        int utf16Length)
    {
        Key = key;
        Display = display;
        GroupId = groupId;
        Category = category;
        Utf16Start = utf16Start;
        Utf16Length = utf16Length;
    }
}

public sealed class ResultLayout
{
    public static ResultLayout Empty { get; } = new(
        "",
        [],
        new Dictionary<KerningGroup, int>(),
        []);

    public string Text { get; }
    public string ViewText { get; }
    public IReadOnlyList<ResultToken> Tokens { get; }
    public IReadOnlyDictionary<KerningGroup, int> CategoryStarts { get; }
    public IReadOnlyList<ResultCategory> Categories { get; }

    public ResultLayout(
        string text,
        IReadOnlyList<ResultToken> tokens,
        IReadOnlyDictionary<KerningGroup, int> categoryStarts,
        IReadOnlyList<ResultCategory> categories)
    {
        Text = text;
        Tokens = tokens;
        CategoryStarts = categoryStarts;
        Categories = categories;
        ViewText = TokenGlue.ViewText(text, tokens);
    }

    public bool IsEmpty => Text.Length == 0;

    public bool HasCategory(KerningGroup group) => CategoryStarts.ContainsKey(group);

    public (int Done, int Total) Progress(KerningGroup group, IReadOnlySet<string> done) =>
        ProgressByCategory(done).GetValueOrDefault(group);

    public Dictionary<KerningGroup, (int Done, int Total)> ProgressByCategory(IReadOnlySet<string> done)
    {
        var totals = new Dictionary<KerningGroup, (int Done, int Total)>();
        foreach (var token in Tokens)
        {
            totals.TryGetValue(token.Category, out var entry);
            entry.Total++;
            if (done.Contains(token.Key))
            {
                entry.Done++;
            }

            totals[token.Category] = entry;
        }

        return totals;
    }

    public static ResultLayout Build(
        IReadOnlyList<RecipeSection> sections,
        ResultLayoutMode mode = ResultLayoutMode.Column)
    {
        var recipeByLine = KerningPlan.Recipes.ToDictionary(recipe => recipe.Line, recipe => recipe);
        var text = new System.Text.StringBuilder();
        var tokens = new List<ResultToken>();
        var categoryStarts = new Dictionary<KerningGroup, int>();
        var groupCounters = new Dictionary<KerningGroup, int>();
        var categories = new List<ResultCategory>();
        KerningGroup? currentCategory = null;
        var currentBlocks = new List<ResultGroup>();
        var pairSeparator = mode == ResultLayoutMode.Row ? "  " : "\n";

        void FlushCategory()
        {
            if (currentCategory is { } group && currentBlocks.Count > 0)
            {
                categories.Add(new ResultCategory(group, currentBlocks.ToList()));
                currentBlocks.Clear();
            }
        }

        for (var sectionIndex = 0; sectionIndex < sections.Count; sectionIndex++)
        {
            if (sectionIndex > 0)
            {
                text.Append("\n\n\n");
            }

            var section = sections[sectionIndex];
            if (!recipeByLine.TryGetValue(section.Recipe, out var recipe))
            {
                continue;
            }

            var category = recipe.Left;
            if (currentCategory != category)
            {
                FlushCategory();
                currentCategory = category;
            }

            for (var blockIndex = 0; blockIndex < section.PairGroups.Count; blockIndex++)
            {
                if (blockIndex > 0)
                {
                    text.Append("\n\n");
                }

                if (!categoryStarts.ContainsKey(category))
                {
                    categoryStarts[category] = text.Length;
                }

                var index = groupCounters.GetValueOrDefault(category);
                groupCounters[category] = index + 1;
                var groupId = $"{KerningPlan.Code(category)}-{index}";
                var pairs = section.PairGroups[blockIndex];
                for (var pairIndex = 0; pairIndex < pairs.Count; pairIndex++)
                {
                    if (pairIndex > 0)
                    {
                        text.Append(pairSeparator);
                    }

                    var pair = pairs[pairIndex];
                    var start = text.Length;
                    text.Append(pair.Display);
                    tokens.Add(new ResultToken(
                        pair.Key,
                        pair.Display,
                        groupId,
                        category,
                        start,
                        pair.Display.Length));
                }

                currentBlocks.Add(new ResultGroup(groupId, category, pairs));
            }
        }

        FlushCategory();
        return new ResultLayout(text.ToString(), tokens, categoryStarts, categories);
    }

    public ResultToken? TokenAtUtf16(int index)
    {
        foreach (var token in Tokens)
        {
            if (index >= token.Utf16Start && index < token.Utf16End)
            {
                return token;
            }
        }

        return NearestToken(index);
    }

    public ResultToken? NearestToken(int index)
    {
        ResultToken? best = null;
        var bestDistance = int.MaxValue;
        foreach (var token in Tokens)
        {
            int distance;
            if (index < token.Utf16Start)
            {
                distance = token.Utf16Start - index;
            }
            else if (index >= token.Utf16End)
            {
                distance = index - token.Utf16End + 1;
            }
            else
            {
                return token;
            }

            if (distance < bestDistance)
            {
                bestDistance = distance;
                best = token;
            }
        }

        return best;
    }

    public IReadOnlyList<ResultToken> TokensInUtf16(int start, int length)
    {
        if (length <= 0)
        {
            var token = TokenAtUtf16(start);
            return token is null ? [] : [token];
        }

        var end = start + length;
        return Tokens.Where(token => token.Utf16Start < end && token.Utf16End > start).ToList();
    }

    public IReadOnlyList<string> GroupKeys(string groupId) =>
        Tokens.Where(token => token.GroupId == groupId).Select(token => token.Key).ToList();

    public (int Start, int Length)? Utf16Range(string groupId)
    {
        ResultToken? first = null;
        ResultToken? last = null;
        foreach (var token in Tokens)
        {
            if (token.GroupId != groupId)
            {
                continue;
            }

            first ??= token;
            last = token;
        }

        if (first is null || last is null)
        {
            return null;
        }

        return (first.Utf16Start, last.Utf16End - first.Utf16Start);
    }

    public KerningGroup? CategoryAtUtf16(int index)
    {
        KerningGroup? match = null;
        var bestStart = -1;
        foreach (var (group, start) in CategoryStarts)
        {
            if (start <= index && start >= bestStart)
            {
                bestStart = start;
                match = group;
            }
        }

        return match;
    }

    public Dictionary<string, HashSet<string>> KeysByGroup()
    {
        var keys = new Dictionary<string, HashSet<string>>();
        foreach (var token in Tokens)
        {
            if (!keys.TryGetValue(token.GroupId, out var group))
            {
                group = [];
                keys[token.GroupId] = group;
            }

            group.Add(token.Key);
        }

        return keys;
    }

    public bool HasMixedGroups(KerningMarkState state) =>
        KeysByGroup().Values.Any(keys => state.GroupMark(keys.ToList()) == GroupMark.MixedDone);
}

public static class NewUnkernedNotice
{
    public static (HashSet<string> WarningGroupIds, HashSet<string> NewKeys) Update(
        IReadOnlyDictionary<string, HashSet<string>> previous,
        IReadOnlyDictionary<string, HashSet<string>> current,
        IReadOnlySet<string> done,
        IReadOnlySet<string> warningGroupIds,
        IReadOnlySet<string> newKeys)
    {
        var warning = new HashSet<string>(warningGroupIds);
        var news = new HashSet<string>(newKeys);
        var firstPass = previous.Count == 0;
        foreach (var (groupId, keys) in current)
        {
            if (!IsMixed(keys, done))
            {
                warning.Remove(groupId);
                news.ExceptWith(keys);
                continue;
            }

            if (firstPass)
            {
                continue;
            }

            var before = previous.TryGetValue(groupId, out var prior) ? prior : [];
            var added = keys.Except(before).ToHashSet();
            var hadDone = before.Overlaps(done);
            if (added.Count > 0 && hadDone)
            {
                warning.Add(groupId);
                news.UnionWith(added);
            }
        }

        warning.RemoveWhere(groupId => !current.ContainsKey(groupId));
        var known = current.Values.SelectMany(keys => keys).ToHashSet();
        news.IntersectWith(known);
        return (warning, news);
    }

    private static bool IsMixed(HashSet<string> keys, IReadOnlySet<string> done)
    {
        if (keys.Count == 0)
        {
            return false;
        }

        var doneCount = keys.Count(done.Contains);
        return doneCount > 0 && doneCount < keys.Count;
    }
}

public static class ResultSelectionMarks
{
    public static bool CanStrike(IReadOnlyList<string> keys, KerningMarkState state) =>
        keys.Any(key => state.PairMark(key) == PairMark.Empty);

    public static bool CanUnstrike(IReadOnlyList<string> keys, KerningMarkState state) =>
        keys.Any(key => state.PairMark(key) == PairMark.Done);

    public static KerningMarkState Strike(IReadOnlyList<string> keys, KerningMarkState state) =>
        KerningMarks.MarkDone(keys, state);

    public static KerningMarkState Unstrike(IReadOnlyList<string> keys, KerningMarkState state)
    {
        var next = new HashSet<string>(state.Done);
        foreach (var key in keys)
        {
            next.Remove(key);
        }

        return new KerningMarkState(next);
    }
}
