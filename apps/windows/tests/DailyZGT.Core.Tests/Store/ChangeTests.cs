using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using Microsoft.Extensions.Time.Testing;

namespace DailyZGT.Core.Tests.Store;

public sealed class ChangeTests : IDisposable
{
    private const string InsertFromAnotherWriter = """
        INSERT INTO priority (id, title, level, list, position, created_at, updated_at)
        VALUES ('p1', 'From another writer', 'high', 'today', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')
        """;

    private readonly TestStore _test = new();
    private AppStore Store => _test.Store;

    public void Dispose() => _test.Dispose();

    [Fact]
    public void AWriteRaisesOneChangeWithTheNewSnapshot()
    {
        var seen = new List<int>();
        Store.Changed += (_, _) => seen.Add(Store.OpenCount(PriorityList.Today));

        Store.Add("Observed");

        Assert.Equal([1], seen);
    }

    [Fact]
    public void EachKindOfWriteRaisesExactlyOneChange()
    {
        var priority = Store.Add("Observed");
        var actions = new Action[]
        {
            () => Store.EditTitle(priority.Id, "Renamed"),
            () => Store.MoveToList(priority.Id, PriorityList.Week),
            () => Store.AddSubtask(priority.Id, "Step"),
            () => Store.MarkDone(priority.Id),
            () => Store.Restore(priority.Id),
            () => Store.SaveNote(NoteScope.Day, "Note"),
            () => Store.SetValue(AppStateKeys.DoneOpen, true),
            () => Store.SaveAlerts([new PriorityAlert("a1", priority.Id, AlertKind.AtDue, _test.Clock.Now, AlertStatus.Scheduled)]),
            () => Store.Delete(priority.Id),
        };
        foreach (var action in actions)
        {
            var before = _test.Changes;
            action();
            Assert.Equal(before + 1, _test.Changes);
        }
    }

    [Fact]
    public void AnOwnWriteIsNotAnExternalChange()
    {
        Store.Add("Mine");
        Assert.False(Store.CheckForExternalChanges());
    }

    [Fact]
    public void AWriteFromAnotherConnectionShowsAfterTheCheck()
    {
        _test.Execute(InsertFromAnotherWriter);
        var before = _test.Changes;

        Assert.True(Store.CheckForExternalChanges());

        Assert.Equal(["From another writer"], Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Equal(before + 1, _test.Changes);
        Assert.False(Store.CheckForExternalChanges());
        Assert.Equal(before + 1, _test.Changes);
    }

    [Fact]
    public void AWriteOfTheStoreAfterAnExternalWriteShowsBothAndIsNotSeenTwice()
    {
        _test.Execute(InsertFromAnotherWriter);
        Store.Add("Mine");

        Assert.Equal(["From another writer", "Mine"], Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.False(Store.CheckForExternalChanges());
    }

    [Fact]
    public void TheWatcherChecksOnTheUIThreadEverySecond()
    {
        var time = new FakeTimeProvider();
        var uiThread = new RecordingContext();
        using var watcher = new ExternalChangeWatcher(Store, uiThread, time);
        var before = _test.Changes;

        time.Advance(TimeSpan.FromMilliseconds(999));
        _test.Execute(InsertFromAnotherWriter);
        Assert.Equal(0, uiThread.Posts);

        time.Advance(TimeSpan.FromMilliseconds(1));

        Assert.Equal(1, uiThread.Posts);
        Assert.Equal(before + 1, _test.Changes);
        Assert.Equal(["From another writer"], Store.OpenPriorities(PriorityList.Today).Titles());

        time.Advance(TimeSpan.FromSeconds(1));
        Assert.Equal(2, uiThread.Posts);
        Assert.Equal(before + 1, _test.Changes);
    }

    [Fact]
    public void TheWatcherStopsWhenDisposed()
    {
        var time = new FakeTimeProvider();
        var uiThread = new RecordingContext();
        var watcher = new ExternalChangeWatcher(Store, uiThread, time);
        watcher.Dispose();
        _test.Execute(InsertFromAnotherWriter);
        var before = _test.Changes;

        time.Advance(TimeSpan.FromSeconds(5));

        Assert.Equal(before, _test.Changes);
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
    }

    private sealed class RecordingContext : SynchronizationContext
    {
        public int Posts { get; private set; }

        public override void Post(SendOrPostCallback callback, object? state)
        {
            Posts++;
            callback(state);
        }
    }
}
