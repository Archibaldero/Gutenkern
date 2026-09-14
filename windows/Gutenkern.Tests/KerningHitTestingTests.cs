using Xunit;

namespace Gutenkern.Tests;

public sealed class KerningHitTestingTests
{
    private static readonly PairHitFrame Left = new("/a/a/a", 10, 5, 40, 16);
    private static readonly PairHitFrame Right = new("/a/b/a", 70, 5, 40, 16);

    private static readonly PairHitFrame[] Row = [Left, Right];

    [Fact]
    public void NearestKey_returns_null_when_empty()
    {
        Assert.Null(PairHitTesting.NearestKey(0, 0, []));
    }

    [Fact]
    public void NearestKey_hits_the_frame_that_contains_the_point()
    {
        Assert.Equal("/a/a/a", PairHitTesting.NearestKey(20, 10, Row));
        Assert.Equal("/a/b/a", PairHitTesting.NearestKey(90, 12, Row));
    }

    [Fact]
    public void NearestKey_gap_goes_to_the_closer_pair()
    {
        Assert.Equal("/a/a/a", PairHitTesting.NearestKey(54, 12, Row));
        Assert.Equal("/a/b/a", PairHitTesting.NearestKey(61, 12, Row));
    }

    [Fact]
    public void NearestKey_empty_space_to_the_right_selects_the_last_pair()
    {
        Assert.Equal("/a/b/a", PairHitTesting.NearestKey(400, 12, Row));
    }

    [Fact]
    public void NearestKey_padding_around_the_row_selects_the_nearest_pair()
    {
        Assert.Equal("/a/a/a", PairHitTesting.NearestKey(2, 2, Row));
        Assert.Equal("/a/b/a", PairHitTesting.NearestKey(120, 30, Row));
    }
}
