using System.Text.Json;
using Xunit;

namespace Gutenkern.Tests;

public sealed class KerningGeneratorTests
{
    [Fact]
    public void Parse_matches_all_fixtures()
    {
        var fixtures = FixturesFile.Load();
        Assert.NotEmpty(fixtures.Parse);

        foreach (var testCase in fixtures.Parse)
        {
            var parsed = KerningGenerator.Parse(testCase.Input);
            var actual = parsed.Select(Describe).ToList();
            var expected = testCase.Glyphs.Select(glyph => (glyph.Type, glyph.Value)).ToList();
            Assert.Equal(expected, actual);
        }
    }

    [Fact]
    public void Generate_matches_all_fixtures()
    {
        var fixtures = FixturesFile.Load();
        Assert.NotEmpty(fixtures.Generate);

        foreach (var testCase in fixtures.Generate)
        {
            var actual = KerningGenerator.Generate(
                testCase.Left,
                testCase.Right,
                ParseMode(testCase.Mode),
                ParseFormat(testCase.Format)
            );
            Assert.Equal(testCase.Expected, actual);
        }
    }

    [Fact]
    public void Plan_matches_all_fixtures()
    {
        var fixtures = FixturesFile.Load();
        Assert.NotEmpty(fixtures.Plan);

        foreach (var testCase in fixtures.Plan)
        {
            var selected = testCase.Selected.Select(KerningPlan.Parse);
            var actual = KerningPlan.Text(selected);
            Assert.Equal(testCase.Expected, actual);
        }
    }

    private static (string Type, string Value) Describe(Glyph glyph) => glyph switch
    {
        CharacterGlyph character => ("character", character.Value),
        NameGlyph name => ("name", name.Value),
        _ => throw new InvalidOperationException(glyph.GetType().Name)
    };

    private static PairMode ParseMode(string value) => value switch
    {
        "simple" => PairMode.Simple,
        "mirror" => PairMode.Mirror,
        _ => throw new InvalidOperationException($"Unknown mode: {value}")
    };

    private static OutputFormat ParseFormat(string value) => value switch
    {
        "fontlab" => OutputFormat.FontLab,
        "glyphs" => OutputFormat.Glyphs,
        _ => throw new InvalidOperationException($"Unknown format: {value}")
    };
}

internal static class FixturesFile
{
    public static Fixtures Load()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "fixtures.json");
        var json = File.ReadAllText(path);
        var fixtures = JsonSerializer.Deserialize<Fixtures>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
        return fixtures ?? throw new InvalidOperationException("fixtures.json is empty");
    }
}

internal sealed class Fixtures
{
    public List<ParseCase> Parse { get; set; } = [];
    public List<GenerateCase> Generate { get; set; } = [];
    public List<PlanCase> Plan { get; set; } = [];
}

internal sealed class ParseCase
{
    public string Id { get; set; } = "";
    public string Input { get; set; } = "";
    public List<GlyphDto> Glyphs { get; set; } = [];
}

internal sealed class GlyphDto
{
    public string Type { get; set; } = "";
    public string Value { get; set; } = "";
}

internal sealed class GenerateCase
{
    public string Id { get; set; } = "";
    public string Left { get; set; } = "";
    public string Right { get; set; } = "";
    public string Mode { get; set; } = "";
    public string Format { get; set; } = "";
    public string Expected { get; set; } = "";
}

internal sealed class PlanCase
{
    public string Id { get; set; } = "";
    public List<string> Selected { get; set; } = [];
    public string Expected { get; set; } = "";
}
