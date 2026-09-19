namespace Gutenkern;

public enum PairMark
{
    Empty,
    Done
}

public enum GroupMark
{
    Empty,
    Done,
    MixedDone
}

public sealed class KerningMarkState
{
    public HashSet<string> Done { get; }

    public KerningMarkState(IEnumerable<string> done)
    {
        Done = [.. done];
    }

    public PairMark PairMark(string key) =>
        Done.Contains(key) ? Gutenkern.PairMark.Done : Gutenkern.PairMark.Empty;

    public GroupMark GroupMark(IReadOnlyList<string> keys)
    {
        if (keys.Count == 0)
        {
            return Gutenkern.GroupMark.Empty;
        }

        var doneCount = 0;
        foreach (var key in keys)
        {
            if (PairMark(key) == Gutenkern.PairMark.Done)
            {
                doneCount++;
            }
        }

        if (doneCount == keys.Count)
        {
            return Gutenkern.GroupMark.Done;
        }

        if (doneCount > 0)
        {
            return Gutenkern.GroupMark.MixedDone;
        }

        return Gutenkern.GroupMark.Empty;
    }
}

public static class KerningMarks
{
    public static KerningMarkState MarkDone(IReadOnlyList<string> keys, KerningMarkState state)
    {
        var next = Copy(state);
        foreach (var key in keys)
        {
            next.Done.Add(key);
        }

        return next;
    }

    private static KerningMarkState Copy(KerningMarkState state) => new(state.Done);
}
