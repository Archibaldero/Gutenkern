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
    public static KerningMarkState ToggleGroup(IReadOnlyList<string> keys, KerningMarkState state)
    {
        var next = Copy(state);
        if (state.GroupMark(keys) == GroupMark.Done)
        {
            foreach (var key in keys)
            {
                next.Done.Remove(key);
            }
        }
        else
        {
            foreach (var key in keys)
            {
                next.Done.Add(key);
            }
        }

        return next;
    }

    public static KerningMarkState TogglePair(string key, KerningMarkState state)
    {
        var next = Copy(state);
        if (state.PairMark(key) == PairMark.Done)
        {
            next.Done.Remove(key);
        }
        else
        {
            next.Done.Add(key);
        }

        return next;
    }

    public static KerningMarkState MarkDone(IReadOnlyList<string> keys, KerningMarkState state)
    {
        var next = Copy(state);
        foreach (var key in keys)
        {
            next.Done.Add(key);
        }

        return next;
    }

    public static KerningMarkState Prune(KerningMarkState state, IReadOnlySet<string> known) =>
        new(state.Done.Intersect(known));

    private static KerningMarkState Copy(KerningMarkState state) => new(state.Done);
}
