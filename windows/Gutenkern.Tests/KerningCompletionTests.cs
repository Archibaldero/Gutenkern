using Xunit;

namespace Gutenkern.Tests;

public sealed class KerningCompletionTests
{
    private static readonly RecipeSection Capitals = new(
        "A/A/A",
        ["A/H/A\nA/A/A", "H/A/H\nH/H/H"]);

    private static readonly RecipeSection Lowercase = new(
        "a/a/a",
        ["n/o/n\nn/n/n", "o/n/o\no/o/o"]);

    private static IReadOnlyList<RecipeSection> Sections => [Capitals, Lowercase];

    [Fact]
    public void ToggleRecipe_marks_and_unmarks_all_groups()
    {
        var completion = new KerningCompletion([], []);

        completion.ToggleRecipe("A/A/A", Sections);

        Assert.Contains("A/A/A", completion.Recipes);
        Assert.True(completion.IsRecipeDone("A/A/A", Sections));
        Assert.All(Capitals.Groups, group => Assert.True(completion.IsBlockDone(group)));
        Assert.DoesNotContain("a/a/a", completion.Recipes);
        Assert.All(Lowercase.Groups, group => Assert.False(completion.IsBlockDone(group)));

        completion.ToggleRecipe("A/A/A", Sections);

        Assert.DoesNotContain("A/A/A", completion.Recipes);
        Assert.False(completion.IsRecipeDone("A/A/A", Sections));
        Assert.All(Capitals.Groups, group => Assert.False(completion.IsBlockDone(group)));
    }

    [Fact]
    public void ToggleBlock_marks_recipe_only_when_all_groups_are_done()
    {
        var completion = new KerningCompletion([], []);

        completion.ToggleBlock(Capitals.Groups[0], Sections);
        Assert.True(completion.IsBlockDone(Capitals.Groups[0]));
        Assert.False(completion.IsRecipeDone("A/A/A", Sections));

        completion.ToggleBlock(Capitals.Groups[1], Sections);
        Assert.True(completion.IsRecipeDone("A/A/A", Sections));
        Assert.Contains("A/A/A", completion.Recipes);

        completion.ToggleBlock(Capitals.Groups[1], Sections);
        Assert.False(completion.IsRecipeDone("A/A/A", Sections));
        Assert.True(completion.IsBlockDone(Capitals.Groups[0]));
        Assert.DoesNotContain("A/A/A", completion.Recipes);
    }

    [Fact]
    public void Sync_applies_legacy_recipe_marks_to_groups()
    {
        var completion = new KerningCompletion(["A/A/A"], []);
        completion.Sync(Sections);

        Assert.Contains("A/A/A", completion.Recipes);
        Assert.All(Capitals.Groups, group => Assert.True(completion.IsBlockDone(group)));
        Assert.All(Lowercase.Groups, group => Assert.False(completion.IsBlockDone(group)));
    }

    [Fact]
    public void Sync_marks_recipe_when_all_groups_are_already_done()
    {
        var completion = new KerningCompletion([], Capitals.Groups);
        completion.Sync(Sections);

        Assert.Contains("A/A/A", completion.Recipes);
        Assert.DoesNotContain("a/a/a", completion.Recipes);
    }

    [Fact]
    public void GenerateRecipeSections_keeps_recipe_identity()
    {
        var sections = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("AH"),
            OutputFormat.FontLab);

        Assert.Equal(["A/A/A"], sections.Select(section => section.Recipe));
        Assert.Equal(2, sections[0].Groups.Count);
        Assert.Equal(
            KerningGenerator.GenerateSections(GlyphClassifier.Classify("AH"), OutputFormat.FontLab),
            sections.Select(section => section.Groups.ToList()).ToList());
    }

    [Fact]
    public void Sync_keeps_done_pairs_when_a_glyph_is_added()
    {
        var before = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("HO"),
            OutputFormat.FontLab);
        var after = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("HOA"),
            OutputFormat.FontLab);
        var oldKeys = before[0].PairGroups[0].Select(pair => pair.Key).ToList();
        var newGroup = after[0].PairGroups.First(group => group[0].Key.StartsWith("/H/", StringComparison.Ordinal));

        var completion = new KerningCompletion([], oldKeys);
        completion.Sync(after);

        Assert.All(oldKeys, key => Assert.Contains(key, completion.Blocks));
        Assert.Contains(newGroup, pair => !completion.Blocks.Contains(pair.Key));
        Assert.False(completion.IsRecipeDone("A/A/A", after));
    }

    [Fact]
    public void Pair_keys_are_fontlab_regardless_of_output_format()
    {
        var fontlab = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("HO"),
            OutputFormat.FontLab);
        var glyphs = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("HO"),
            OutputFormat.Glyphs);

        Assert.Equal(
            fontlab[0].PairGroups[0].Select(pair => pair.Key),
            glyphs[0].PairGroups[0].Select(pair => pair.Key));
    }
}

public sealed class KerningMarksTests
{
    private static readonly string[] Keys = ["H/H/H", "H/O/H", "H/A/H"];

    [Fact]
    public void ToggleGroup_marks_empty_group_done()
    {
        var next = KerningMarks.ToggleGroup(Keys, new KerningMarkState([]));

        Assert.Equal(GroupMark.Done, next.GroupMark(Keys));
    }

    [Fact]
    public void ToggleGroup_clears_fully_done_group()
    {
        var state = new KerningMarkState(Keys);
        var next = KerningMarks.ToggleGroup(Keys, state);

        Assert.Equal(GroupMark.Empty, next.GroupMark(Keys));
        Assert.Empty(next.Done);
    }

    [Fact]
    public void ToggleGroup_marks_mixed_group_done()
    {
        var state = new KerningMarkState(["H/H/H", "H/O/H"]);
        Assert.Equal(GroupMark.MixedDone, state.GroupMark(Keys));

        var next = KerningMarks.ToggleGroup(Keys, state);

        Assert.Equal(GroupMark.Done, next.GroupMark(Keys));
    }

    [Fact]
    public void TogglePair_cycles_empty_and_done()
    {
        var done = KerningMarks.TogglePair("H/A/H", new KerningMarkState([]));
        Assert.Equal(PairMark.Done, done.PairMark("H/A/H"));

        var empty = KerningMarks.TogglePair("H/A/H", done);
        Assert.Equal(PairMark.Empty, empty.PairMark("H/A/H"));
    }

    [Fact]
    public void MarkDone_does_not_clear_existing_done_pairs()
    {
        var state = new KerningMarkState(["H/A/H"]);
        var next = KerningMarks.MarkDone(["H/A/H", "H/O/H"], state);

        Assert.Equal(["H/A/H", "H/O/H"], next.Done.OrderBy(key => key).ToArray());
    }
}
