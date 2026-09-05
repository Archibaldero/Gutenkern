using Xunit;

namespace Gutenkern.Tests;

public sealed class SessionSnapshotTests
{
    [Fact]
    public void Sanitize_keeps_field_and_sorts_recipes()
    {
        var snapshot = SessionSnapshot.Sanitize(new SessionSnapshot
        {
            Field1 = "AV",
            Field2 = "ignored",
            Groups = ["A", "unknown", "a"],
            CompletedRecipes = ["A/A/A", "", "a/a/a"],
            Mode = "mirror",
            Format = "glyphs"
        });

        Assert.Equal("AV", snapshot.Field1);
        Assert.Equal("", snapshot.Field2);
        Assert.Empty(snapshot.Groups);
        Assert.Equal(["A/A/A", "a/a/a"], snapshot.CompletedRecipes);
        Assert.Equal(OutputFormat.Glyphs, snapshot.OutputFormatValue);
    }

    [Fact]
    public void Sanitize_falls_back_to_fontlab_for_unknown_format()
    {
        var snapshot = SessionSnapshot.Sanitize(new SessionSnapshot
        {
            Format = "otf"
        });

        Assert.Equal(OutputFormat.FontLab, snapshot.OutputFormatValue);
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
        Assert.Empty(snapshot.CompletedRecipes);
        Assert.Equal(OutputFormat.FontLab, snapshot.OutputFormatValue);
    }
}
