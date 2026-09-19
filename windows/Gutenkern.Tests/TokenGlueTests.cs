using Xunit;

namespace Gutenkern.Tests;

public sealed class TokenGlueTests
{
    [Fact]
    public void Apply_inserts_joiners_and_strip_round_trips()
    {
        const string token = "/A/B";
        var glued = TokenGlue.Apply(token);
        Assert.Equal(token, TokenGlue.Strip(glued));
        Assert.Equal(token, TokenGlue.Clean(glued));
        Assert.DoesNotContain(TokenGlue.Joiner, TokenGlue.Clean(glued));
        Assert.DoesNotContain(TokenGlue.ViewSlash, TokenGlue.Clean(glued));
        Assert.Contains(TokenGlue.Joiner, glued);
        Assert.Contains(TokenGlue.ViewSlash, glued);
        Assert.DoesNotContain('/', glued);
        Assert.NotEqual(token, glued);
        Assert.Equal("", TokenGlue.Apply(""));
        Assert.Equal("A", TokenGlue.Apply("A"));
    }

    [Fact]
    public void View_and_layout_indexes_round_trip()
    {
        var glued = TokenGlue.Apply("/A/B");
        var view = TokenGlue.ViewIndex(glued, 2);
        Assert.Equal(2, TokenGlue.LayoutIndex(glued, view));
    }

    [Fact]
    public void ViewText_strips_back_to_layout_text()
    {
        var sections = KerningGenerator.GenerateRecipeSections(
            GlyphClassifier.Classify("AH"),
            OutputFormat.FontLab);
        var layout = ResultLayout.Build(sections, ResultLayoutMode.Row);
        Assert.Equal(layout.Text, TokenGlue.Strip(layout.ViewText));
        Assert.NotEqual(layout.Text, layout.ViewText);
        Assert.Equal(layout.Text, TokenGlue.ViewText(layout.Text, layout.Tokens, _ => false));
        Assert.Equal(layout.Text, TokenGlue.Clean(layout.ViewText));
    }
}
