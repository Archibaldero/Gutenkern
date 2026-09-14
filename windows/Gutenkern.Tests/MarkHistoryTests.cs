using Xunit;

namespace Gutenkern.Tests;

public sealed class MarkHistoryTests
{
    [Fact]
    public void Records_undo_and_redo_steps()
    {
        var history = new MarkHistory();
        var empty = new KerningMarkState([]);
        var first = new KerningMarkState(["H/A/H"]);
        var second = new KerningMarkState(["H/A/H", "H/O/H"]);

        history.Record(empty, empty);
        Assert.False(history.CanUndo);

        history.Record(empty, first);
        history.Record(first, second);

        var firstUndo = history.Undo(second);
        Assert.NotNull(firstUndo);
        Assert.Equal(["H/A/H"], firstUndo!.Done.ToArray());

        var secondUndo = history.Undo(firstUndo);
        Assert.NotNull(secondUndo);
        Assert.Empty(secondUndo!.Done);
        Assert.False(history.CanUndo);

        var redo = history.Redo(secondUndo);
        Assert.NotNull(redo);
        Assert.Equal(["H/A/H"], redo!.Done.ToArray());

        history.Record(redo, empty);
        Assert.False(history.CanRedo);
    }

    [Fact]
    public void Coalesces_paint_into_one_step()
    {
        var history = new MarkHistory();
        var empty = new KerningMarkState([]);
        var first = new KerningMarkState(["H/A/H"]);
        var second = new KerningMarkState(["H/A/H", "H/O/H"]);

        history.BeginCoalescing();
        history.Record(empty, first);
        history.Record(first, second);
        history.EndCoalescing();

        var undone = history.Undo(second);
        Assert.NotNull(undone);
        Assert.Empty(undone!.Done);
        Assert.Null(history.Undo(undone));
    }
}
