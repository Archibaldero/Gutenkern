namespace Gutenkern;

public sealed class MarkHistory
{
    private readonly List<KerningMarkState> _undo = [];
    private readonly List<KerningMarkState> _redo = [];
    private bool _coalescing;
    private bool _coalesced;

    public bool CanUndo => _undo.Count > 0;
    public bool CanRedo => _redo.Count > 0;

    public void Record(KerningMarkState previous, KerningMarkState next)
    {
        if (Same(previous, next))
        {
            return;
        }

        if (_coalescing)
        {
            if (!_coalesced)
            {
                _undo.Add(Copy(previous));
                _redo.Clear();
                _coalesced = true;
            }

            return;
        }

        _undo.Add(Copy(previous));
        _redo.Clear();
    }

    public void BeginCoalescing()
    {
        _coalescing = true;
        _coalesced = false;
    }

    public void EndCoalescing()
    {
        _coalescing = false;
        _coalesced = false;
    }

    public KerningMarkState? Undo(KerningMarkState current)
    {
        if (_undo.Count == 0)
        {
            return null;
        }

        var previous = _undo[^1];
        _undo.RemoveAt(_undo.Count - 1);
        _redo.Add(Copy(current));
        return previous;
    }

    public KerningMarkState? Redo(KerningMarkState current)
    {
        if (_redo.Count == 0)
        {
            return null;
        }

        var next = _redo[^1];
        _redo.RemoveAt(_redo.Count - 1);
        _undo.Add(Copy(current));
        return next;
    }

    private static bool Same(KerningMarkState left, KerningMarkState right) =>
        left.Done.SetEquals(right.Done);

    private static KerningMarkState Copy(KerningMarkState state) =>
        new(state.Done);
}
