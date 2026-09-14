namespace Gutenkern;

public readonly struct PairHitFrame
{
    public string Key { get; }
    public double X { get; }
    public double Y { get; }
    public double Width { get; }
    public double Height { get; }

    public PairHitFrame(string key, double x, double y, double width, double height)
    {
        Key = key;
        X = x;
        Y = y;
        Width = width;
        Height = height;
    }
}

public static class PairHitTesting
{
    public static string? NearestKey(double x, double y, IReadOnlyList<PairHitFrame> frames)
    {
        string? bestKey = null;
        var bestDistance = double.PositiveInfinity;
        foreach (var frame in frames)
        {
            var distance = DistanceToRect(x, y, frame);
            if (distance < bestDistance)
            {
                bestDistance = distance;
                bestKey = frame.Key;
            }
        }

        return bestKey;
    }

    private static double DistanceToRect(double x, double y, PairHitFrame frame)
    {
        var minX = frame.X;
        var minY = frame.Y;
        var maxX = frame.X + frame.Width;
        var maxY = frame.Y + frame.Height;
        var dx = 0.0;
        if (x < minX)
        {
            dx = minX - x;
        }
        else if (x > maxX)
        {
            dx = x - maxX;
        }

        var dy = 0.0;
        if (y < minY)
        {
            dy = minY - y;
        }
        else if (y > maxY)
        {
            dy = y - maxY;
        }

        return Math.Sqrt(dx * dx + dy * dy);
    }
}
