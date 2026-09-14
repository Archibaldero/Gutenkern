using Xunit;

namespace Gutenkern.Tests;

public sealed class CopyBurstTests
{
    [Fact]
    public void Collects_unique_keys_in_click_order()
    {
        var burst = new CopyBurst();
        var start = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);

        Assert.Equal(["H/A/H"], burst.Add("H/A/H", start));
        Assert.Equal(["H/A/H", "H/O/H"], burst.Add("H/O/H", start.AddMilliseconds(400)));
        Assert.Equal(["H/A/H", "H/O/H"], burst.Add("H/A/H", start.AddMilliseconds(800)));
    }

    [Fact]
    public void Starts_a_new_burst_after_the_window()
    {
        var burst = new CopyBurst();
        var start = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);

        burst.Add("H/A/H", start);
        Assert.Equal(["H/O/H"], burst.Add("H/O/H", start.AddSeconds(1)));
    }

    [Fact]
    public void Reset_clears_the_burst()
    {
        var burst = new CopyBurst();
        var start = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);

        burst.Add("H/A/H", start);
        burst.Reset();
        Assert.Equal(["H/O/H"], burst.Add("H/O/H", start.AddMilliseconds(200)));
    }
}
