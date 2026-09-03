using Xunit;

namespace Gutenkern.Tests;

public sealed class SessionSnapshotTests
{
    [Fact]
    public void Sanitize_drops_unknown_groups_and_sorts_recipes()
    {
        var snapshot = SessionSnapshot.Sanitize(new SessionSnapshot
        {
            Field1 = "AV",
            Field2 = "To",
            Groups = ["A", "unknown", "a"],
            CompletedRecipes = ["A/A/A", "", "a/a/a"],
            Mode = "mirror",
            Format = "glyphs"
        });

        Assert.Equal("AV", snapshot.Field1);
        Assert.Equal("To", snapshot.Field2);
        Assert.Equal(["A", "a"], snapshot.Groups);
        Assert.Equal(["A/A/A", "a/a/a"], snapshot.CompletedRecipes);
        Assert.Equal(PairMode.Mirror, snapshot.PairModeValue);
        Assert.Equal(OutputFormat.Glyphs, snapshot.OutputFormatValue);
    }

    [Fact]
    public void Sanitize_falls_back_to_defaults_for_unknown_mode_and_format()
    {
        var snapshot = SessionSnapshot.Sanitize(new SessionSnapshot
        {
            Mode = "sideways",
            Format = "otf"
        });

        Assert.Equal(PairMode.Simple, snapshot.PairModeValue);
        Assert.Equal(OutputFormat.FontLab, snapshot.OutputFormatValue);
        Assert.Equal("simple", snapshot.Mode);
        Assert.Equal("fontlab", snapshot.Format);
    }

    [Fact]
    public void Sanitize_maps_legacy_plain_format_to_fontlab()
    {
        var snapshot = SessionSnapshot.Sanitize(new SessionSnapshot
        {
            Format = "plain"
        });

        Assert.Equal(OutputFormat.FontLab, snapshot.OutputFormatValue);
        Assert.Equal("fontlab", snapshot.Format);
    }

    [Fact]
    public void Sanitize_null_returns_empty()
    {
        var snapshot = SessionSnapshot.Sanitize(null);
        Assert.Equal("", snapshot.Field1);
        Assert.Empty(snapshot.Groups);
        Assert.Equal(PairMode.Simple, snapshot.PairModeValue);
        Assert.Equal(OutputFormat.FontLab, snapshot.OutputFormatValue);
    }
}
