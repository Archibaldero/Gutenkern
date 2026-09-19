using Xunit;

namespace Gutenkern.Tests;

public sealed class ResultLayoutTests
{
    [Fact]
    public void Build_matches_generated_text_and_maps_tokens()
    {
        var sections = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("AH"),
            OutputFormat.FontLab);
        var layout = ResultLayout.Build(sections, ResultLayoutMode.Column);
        var generated = KerningGenerator.Generate(GlyphClassifier.Classify("AH"), OutputFormat.FontLab);

        Assert.Equal(generated, layout.Text);
        Assert.NotEmpty(layout.Tokens);
        Assert.NotEmpty(layout.Categories);
        Assert.NotEmpty(layout.Categories[0].Blocks);
        Assert.Equal(0, layout.CategoryStarts[KerningGroup.Capitals]);
        Assert.False(layout.HasCategory(KerningGroup.Lowercase));
        Assert.Equal(layout.Tokens[0].Key, layout.TokenAtUtf16(0)?.Key);

        var firstGroup = layout.GroupKeys(layout.Tokens[0].GroupId);
        Assert.True(firstGroup.Count >= 2);
        Assert.NotEmpty(layout.TokensInUtf16(0, 8));

        var mixed = new KerningMarkState([layout.Tokens[0].Key]);
        Assert.True(ResultSelectionMarks.CanStrike(firstGroup, mixed));
        Assert.True(ResultSelectionMarks.CanUnstrike(firstGroup, mixed));

        var allDone = KerningMarks.MarkDone(firstGroup, new KerningMarkState([]));
        Assert.False(ResultSelectionMarks.CanStrike(firstGroup, allDone));
    }

    [Fact]
    public void Build_row_joins_pairs_with_two_spaces()
    {
        var sections = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("AH"),
            OutputFormat.FontLab);
        var column = ResultLayout.Build(sections, ResultLayoutMode.Column);
        var row = ResultLayout.Build(sections, ResultLayoutMode.Row);

        Assert.Equal(column.Tokens.Count, row.Tokens.Count);
        Assert.Equal(column.Tokens[0].GroupId, row.Tokens[1].GroupId);
        Assert.Equal(row.Tokens[0].Utf16End + 2, row.Tokens[1].Utf16Start);
        Assert.Contains("  ", row.Text);
        var groupRange = row.Utf16Range(row.Tokens[0].GroupId);
        Assert.NotNull(groupRange);
        Assert.Equal(row.Tokens[0].Utf16Start, groupRange!.Value.Start);
        Assert.True(groupRange.Value.Length >= row.Tokens[1].Utf16End - row.Tokens[0].Utf16Start);

        var empty = column.Progress(KerningGroup.Capitals, new HashSet<string>());
        Assert.Equal(0, empty.Done);
        Assert.Equal(column.Tokens.Count(token => token.Category == KerningGroup.Capitals), empty.Total);

        var keys = column.Tokens
            .Where(token => token.Category == KerningGroup.Capitals)
            .Select(token => token.Key)
            .ToHashSet();
        var done = column.Progress(KerningGroup.Capitals, keys);
        Assert.Equal(done.Total, done.Done);
        Assert.Equal(0, column.Progress(KerningGroup.Lowercase, keys).Total);
        var byCategory = column.ProgressByCategory(keys);
        Assert.Equal(done, byCategory[KerningGroup.Capitals]);
    }

    [Fact]
    public void Duplicate_tokens_count_as_done_when_their_key_is_marked()
    {
        var layout = ResultLayout.Build(
            KerningGenerator.GenerateRecipeSections(
                GlyphClassifier.Classify("aaaa"),
                OutputFormat.FontLab),
            ResultLayoutMode.Row);

        Assert.Equal(16, layout.Tokens.Count);
        Assert.All(layout.Tokens, token => Assert.Equal("/a/a/a", token.Key));

        var uniqueDone = layout.Tokens.Select(token => token.Key).ToHashSet();
        Assert.Single(uniqueDone);

        var progress = layout.ProgressByCategory(uniqueDone)[KerningGroup.Lowercase];
        Assert.Equal(16, progress.Done);
        Assert.Equal(16, progress.Total);
        Assert.Equal(layout.Tokens.Count(token => uniqueDone.Contains(token.Key)), progress.Done);
    }

    [Fact]
    public void NewUnkernedNotice_command_click_does_not_warn()
    {
        var group = "capitals-0";
        var keys = new HashSet<string> { "/a/a/a", "/a/b/a", "/a/c/a" };
        var current = new Dictionary<string, HashSet<string>> { [group] = keys };
        var (warning, news) = NewUnkernedNotice.Update(
            current,
            current,
            new HashSet<string> { "/a/a/a" },
            new HashSet<string>(),
            new HashSet<string>());
        Assert.Empty(warning);
        Assert.Empty(news);
    }

    [Fact]
    public void NewUnkernedNotice_new_key_in_done_group_warns()
    {
        var group = "capitals-0";
        var previous = new Dictionary<string, HashSet<string>>
        {
            [group] = ["/a/a/a", "/a/b/a"]
        };
        var current = new Dictionary<string, HashSet<string>>
        {
            [group] = ["/a/a/a", "/a/b/a", "/a/c/a"]
        };
        var (warning, news) = NewUnkernedNotice.Update(
            previous,
            current,
            new HashSet<string> { "/a/a/a", "/a/b/a" },
            new HashSet<string>(),
            new HashSet<string>());
        Assert.True(warning.SetEquals(new HashSet<string> { group }));
        Assert.True(news.SetEquals(new HashSet<string> { "/a/c/a" }));
    }

    [Fact]
    public void NewUnkernedNotice_clears_when_group_is_done()
    {
        var group = "capitals-0";
        var keys = new HashSet<string> { "/a/a/a", "/a/b/a", "/a/c/a" };
        var current = new Dictionary<string, HashSet<string>> { [group] = keys };
        var (warning, news) = NewUnkernedNotice.Update(
            current,
            current,
            keys,
            new HashSet<string> { group },
            new HashSet<string> { "/a/c/a" });
        Assert.Empty(warning);
        Assert.Empty(news);
    }

    [Fact]
    public void NewUnkernedNotice_first_pass_ignores_growth()
    {
        var group = "capitals-0";
        var current = new Dictionary<string, HashSet<string>>
        {
            [group] = ["/a/a/a", "/a/b/a"]
        };
        var (warning, news) = NewUnkernedNotice.Update(
            new Dictionary<string, HashSet<string>>(),
            current,
            new HashSet<string> { "/a/a/a" },
            new HashSet<string>(),
            new HashSet<string>());
        Assert.Empty(warning);
        Assert.Empty(news);
    }
}
