using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.Store;

public sealed class SubtaskTests : IDisposable
{
    private readonly TestStore _test = new();
    private AppStore Store => _test.Store;
    private TestClock Clock => _test.Clock;

    public void Dispose() => _test.Dispose();

    [Fact]
    public void AddKeepsTheOrderAndTouchesThePriority()
    {
        var priority = Store.Add("Release");
        Clock.Advance(3);
        var first = Store.AddSubtask(priority.Id, "Write the notes")!;
        var second = Store.AddSubtask(priority.Id, "Tag the build")!;

        Assert.Equal([first, second], Store.Subtasks(priority.Id));
        Assert.Equal([1, 2], Store.Subtasks(priority.Id).Select(s => s.Position));
        Assert.Equal(Clock.Now, first.CreatedAt);
        Assert.Equal(Clock.Now, Store.Find(priority.Id)!.UpdatedAt);
        Assert.Equal([Created, Edited, Edited], Store.Types(priority.Id));
    }

    [Fact]
    public void AddTrimsTheTitleAndABlankTitleAddsNothing()
    {
        var priority = Store.Add("Release");
        Assert.Equal("Tag the build", Store.AddSubtask(priority.Id, "  Tag the build\n")!.Title);
        Assert.Null(Store.AddSubtask(priority.Id, "   "));
        Assert.Single(Store.Subtasks(priority.Id));
        Assert.Equal([Created, Edited], Store.Types(priority.Id));
    }

    [Fact]
    public void ToggleMarksDoneThenOpenAgain()
    {
        var priority = Store.Add("Release");
        var subtask = Store.AddSubtask(priority.Id, "Write the notes")!;
        Store.AddSubtask(priority.Id, "Tag the build");
        Clock.Advance(7);

        var done = Store.ToggleSubtask(subtask.Id);
        Assert.Equal(Clock.Now, done.DoneAt);
        Assert.Equal([true, false], Store.Subtasks(priority.Id).Select(s => s.IsDone));
        Assert.Equal(Clock.Now, Store.Find(priority.Id)!.UpdatedAt);
        Assert.Equal(SubtaskDone, Store.Types(priority.Id)[^1]);

        var open = Store.ToggleSubtask(subtask.Id);
        Assert.Null(open.DoneAt);
        Assert.Equal([false, false], Store.Subtasks(priority.Id).Select(s => s.IsDone));
        Assert.Equal([Created, Edited, Edited, SubtaskDone, Edited], Store.Types(priority.Id));
        Assert.Equal([priority.Id], Store.OpenPriorities(PriorityList.Today).Ids());
    }

    [Fact]
    public void APriorityWithNoSubtasksHasAnEmptyList()
    {
        var priority = Store.Add("Release");
        Assert.Empty(Store.Subtasks(priority.Id));
    }
}
