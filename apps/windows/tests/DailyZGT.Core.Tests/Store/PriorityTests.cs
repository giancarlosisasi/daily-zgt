using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.Store;

public sealed class PriorityTests : IDisposable
{
    private readonly TestStore _test = new();
    private AppStore Store => _test.Store;
    private TestClock Clock => _test.Clock;

    public void Dispose() => _test.Dispose();

    [Fact]
    public void AddWritesTheRowAndTheCreatedEvent()
    {
        var due = Time.At("2026-10-12T16:00:00");
        var outcome = Store.AddPriority("Send the report", PriorityList.Today, PriorityLevel.High, due);

        var added = Assert.IsType<AddOutcome.Added>(outcome).Priority;
        Assert.Equal("Send the report", added.Title);
        Assert.Equal(PriorityLevel.High, added.Level);
        Assert.Equal(PriorityList.Today, added.List);
        Assert.Equal(due, added.DueAt);
        Assert.Null(added.DoneAt);
        Assert.Equal(Clock.Now, added.CreatedAt);
        Assert.Equal(Clock.Now, added.UpdatedAt);
        Assert.Equal(added, Store.Find(added.Id));
        Assert.Equal([added], Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([Created], Store.Types(added.Id));
        Assert.Equal([Clock.Now], Store.Events(added.Id).Select(e => e.At));
    }

    [Fact]
    public void AddUsesMediumLevelNoDueAndNoNoteByDefault()
    {
        var added = Store.Add("Read", PriorityList.Week);
        Assert.Equal(PriorityLevel.Medium, added.Level);
        Assert.Null(added.DueAt);
        Assert.Equal("", added.Note);
        Assert.Equal(RepeatRule.None, added.RepeatRule);
        Assert.Null(added.RepeatSeriesId);
        Assert.Equal([added], Store.OpenPriorities(PriorityList.Week));
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
    }

    [Fact]
    public void AddTrimsTheTitleAndABlankTitleAddsNothing()
    {
        Assert.Equal("Call Ana", Store.Add("  Call Ana \n").Title);
        Assert.IsType<AddOutcome.EmptyTitle>(Store.AddPriority(" \t\n", PriorityList.Today));
        Assert.Single(Store.Snapshot.Open);
    }

    [Fact]
    public void EachEditWritesItsFieldAndTheEditedEvent()
    {
        var added = Store.Add("Draft");
        Clock.Advance(10);
        var due = Time.At("2026-10-12T18:00:00");

        Store.EditTitle(added.Id, "  Final ");
        Store.SetNote(added.Id, "Ask Ana");
        Store.SetLevel(added.Id, PriorityLevel.Low);
        var edited = Store.SetDue(added.Id, due);

        Assert.Equal("Final", edited.Title);
        Assert.Equal("Ask Ana", edited.Note);
        Assert.Equal(PriorityLevel.Low, edited.Level);
        Assert.Equal(due, edited.DueAt);
        Assert.Equal(added.CreatedAt, edited.CreatedAt);
        Assert.Equal(Clock.Now, edited.UpdatedAt);
        Assert.Equal(edited, Store.Find(added.Id));
        Assert.Equal([Created, Edited, Edited, Edited, Edited], Store.Types(added.Id));
    }

    [Fact]
    public void AnEditWithNoChangeWritesNothingAndRaisesNoChange()
    {
        var added = Store.Add("Draft", due: "2026-10-12T18:00:00");
        Clock.Advance(10);
        var changes = _test.Changes;

        Assert.Equal(added, Store.EditTitle(added.Id, " Draft "));
        Assert.Equal(added, Store.EditTitle(added.Id, "   "));
        Assert.Equal(added, Store.SetLevel(added.Id, PriorityLevel.Medium));
        Assert.Equal(added, Store.SetDue(added.Id, Time.At("2026-10-12T18:00:00").AddMilliseconds(300)));
        Assert.Equal(added, Store.SetNote(added.Id, " \n "));
        Assert.Equal(added, Store.SetRepeat(added.Id, RepeatRule.None));
        Assert.Equal(added, Assert.IsType<MoveOutcome.Moved>(Store.MoveToList(added.Id, PriorityList.Today)).Priority);

        Assert.Equal(added, Store.Find(added.Id));
        Assert.Equal([Created], Store.Types(added.Id));
        Assert.Equal(changes, _test.Changes);
    }

    [Fact]
    public void ANoteOfOnlyWhitespaceIsStoredEmpty()
    {
        var added = Store.Add("Draft");
        Store.SetNote(added.Id, "Context");
        Assert.Equal("", Store.SetNote(added.Id, "  \n\t").Note);
        Assert.Equal([""], _test.Rows<string>("SELECT note FROM priority"));
    }

    [Fact]
    public void AMoveChangesTheListAndWritesTheMovedEvent()
    {
        var added = Store.Add("Plan the trip", PriorityList.Week);
        Clock.Advance(5);
        var moved = Assert.IsType<MoveOutcome.Moved>(Store.MoveToList(added.Id, PriorityList.Today)).Priority;

        Assert.Equal(PriorityList.Today, moved.List);
        Assert.Equal(Clock.Now, moved.UpdatedAt);
        Assert.Empty(Store.OpenPriorities(PriorityList.Week));
        Assert.Equal([moved], Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([Created, Moved], Store.Types(added.Id));
    }

    [Fact]
    public void DoneAndRestoreWriteTheirEventsOnce()
    {
        var added = Store.Add("Call the bank");
        Clock.Advance(30);
        var done = Store.MarkDone(added.Id);

        Assert.Equal(Clock.Now, done.DoneAt);
        Assert.Equal(Clock.Now, done.UpdatedAt);
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([done], Store.DonePriorities(PriorityList.Today));
        Assert.Equal(done, Store.Find(added.Id));

        Store.MarkDone(added.Id);
        Assert.Equal([Created, Done], Store.Types(added.Id));

        Clock.Advance(1);
        var restored = Store.Restore(added.Id);
        Assert.Null(restored.DoneAt);
        Assert.Equal(Clock.Now, restored.UpdatedAt);
        Assert.Equal([restored], Store.OpenPriorities(PriorityList.Today));
        Assert.Empty(Store.DonePriorities(PriorityList.Today));

        Store.Restore(added.Id);
        Assert.Equal([Created, Done, Restored], Store.Types(added.Id));
    }

    [Fact]
    public void ARestoredPriorityGetsBackItsPlaceInTheOrder()
    {
        var first = Store.Add("First");
        Store.Add("Second");
        Store.MarkDone(first.Id);
        Store.Add("Third");

        Store.Restore(first.Id);

        Assert.Equal(["First", "Second", "Third"], Store.OpenPriorities(PriorityList.Today).Titles());
    }

    [Fact]
    public void DeleteRemovesThePriorityWithItsSubtasksAndAlerts()
    {
        var kept = Store.Add("Keep");
        var removed = Store.Add("Remove");
        Store.AddSubtask(removed.Id, "One");
        Store.AddSubtask(removed.Id, "Two");
        Store.AddSubtask(kept.Id, "Stays");
        Store.SaveAlerts([
            new PriorityAlert("a1", removed.Id, AlertKind.AtDue, Clock.Now, AlertStatus.Scheduled),
            new PriorityAlert("a2", removed.Id, AlertKind.AtDue, Clock.Now, AlertStatus.Scheduled),
            new PriorityAlert("a3", kept.Id, AlertKind.AtDue, Clock.Now, AlertStatus.Scheduled),
        ]);

        var deleted = Store.Delete(removed.Id);

        Assert.Equal(removed.Id, deleted.Id);
        Assert.Null(Store.Find(removed.Id));
        Assert.Empty(Store.Subtasks(removed.Id));
        Assert.Equal(["Keep"], Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Equal(["Stays"], _test.Rows<string>("SELECT title FROM subtask"));
        Assert.Equal(["a3"], _test.Rows<string>("SELECT id FROM alert"));
    }

    [Fact]
    public void AnActionOnAPriorityThatIsGoneThrowsTheStoreError()
    {
        var gone = Store.Add("Gone");
        Store.Delete(gone.Id);

        Assert.Throws<StoreException>(() => Store.MarkDone(gone.Id));
        Assert.Throws<StoreException>(() => Store.Restore("missing"));
        Assert.Throws<StoreException>(() => Store.Delete("missing"));
        Assert.Throws<StoreException>(() => Store.EditTitle("missing", "Title"));
        Assert.Throws<StoreException>(() => Store.MoveToList("missing", PriorityList.Week));
        Assert.Throws<StoreException>(() => Store.AddSubtask("missing", "One"));
        Assert.Throws<StoreException>(() => Store.ToggleSubtask("missing"));
    }

    [Fact]
    public void OpenPrioritiesSortByLevelThenDueThenAge()
    {
        (string Title, PriorityLevel Level, string? Due)[] rows =
        [
            ("low, no due", PriorityLevel.Low, null),
            ("high, 18:00", PriorityLevel.High, "2026-10-12T18:00:00"),
            ("medium, 10:00, first", PriorityLevel.Medium, "2026-10-12T10:00:00"),
            ("high, no due", PriorityLevel.High, null),
            ("high, 16:00", PriorityLevel.High, "2026-10-12T16:00:00"),
            ("medium, no due", PriorityLevel.Medium, null),
            ("medium, 10:00, second", PriorityLevel.Medium, "2026-10-12T10:00:00"),
            ("low, 08:00", PriorityLevel.Low, "2026-10-12T08:00:00"),
            ("high, the day before", PriorityLevel.High, "2026-10-11T23:00:00"),
        ];
        foreach (var (title, level, due) in rows)
        {
            Store.Add(title, PriorityList.Today, level, due);
        }
        Store.Add("other list", PriorityList.Week, PriorityLevel.High);

        Assert.Equal(
            [
                "high, the day before", "high, 16:00", "high, 18:00", "high, no due",
                "medium, 10:00, first", "medium, 10:00, second", "medium, no due",
                "low, 08:00", "low, no due",
            ],
            Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Equal(["other list"], Store.OpenPriorities(PriorityList.Week).Titles());
    }

    [Fact]
    public void DonePrioritiesShowTheLatestFirst()
    {
        var first = Store.Add("First", level: PriorityLevel.Low);
        var second = Store.Add("Second", level: PriorityLevel.High);
        var third = Store.Add("Third");
        Store.MarkDone(second.Id);
        Clock.Advance(5);
        Store.MarkDone(first.Id);
        Clock.Advance(5);
        Store.MarkDone(third.Id);

        Assert.Equal(["Third", "First", "Second"], Store.DonePriorities(PriorityList.Today).Titles());
    }

    [Fact]
    public void TheOpenCountIsPerList()
    {
        var done = Store.Add("A");
        Store.Add("B");
        Store.Add("C");
        Store.Add("D", PriorityList.Week);
        Store.MarkDone(done.Id);

        Assert.Equal(2, Store.OpenCount(PriorityList.Today));
        Assert.Equal(1, Store.OpenCount(PriorityList.Week));
    }

    [Fact]
    public void DatesAreLocalIsoTextInTheFile()
    {
        var added = Store.AddPriority("Demo", PriorityList.Today, dueAt: Time.At("2026-10-12T16:00:00").AddMilliseconds(400));
        var id = Assert.IsType<AddOutcome.Added>(added).Priority.Id;
        Clock.Now = Clock.Now.AddMinutes(90).AddMilliseconds(700);
        Store.MarkDone(id);

        Assert.Equal(["2026-10-12T16:00:00"], _test.Rows<string>("SELECT due_at FROM priority"));
        Assert.Equal(["2026-10-12T09:00:00"], _test.Rows<string>("SELECT created_at FROM priority"));
        Assert.Equal(["2026-10-12T10:30:00"], _test.Rows<string>("SELECT done_at FROM priority"));
        Assert.Equal(["2026-10-12T10:30:00"], _test.Rows<string>("SELECT updated_at FROM priority"));
        Assert.Equal(["2026-10-12T09:00:00", "2026-10-12T10:30:00"], _test.Rows<string>("SELECT at FROM priority_event ORDER BY id"));
        Assert.Equal(Time.At("2026-10-12T16:00:00"), Store.Find(id)!.DueAt);
    }

    [Fact]
    public void IdsAreUppercaseUuidsLikeTheMacOSApp()
    {
        var id = Store.Add("Demo").Id;
        Assert.True(Guid.TryParse(id, out _));
        Assert.Equal(id.ToUpperInvariant(), id);
    }

    [Fact]
    public void TheRowsSurviveCloseAndOpen()
    {
        var priority = Store.Add("Send the report", PriorityList.Today, PriorityLevel.High, "2026-10-12T16:00:00");
        Store.AddSubtask(priority.Id, "Check the numbers");
        Store.SaveNote(NoteScope.Day, "Call Ana");
        Store.SetValue(AppStateKeys.OpenTab, PanelTab.Notes);

        var reopened = _test.Reopen();

        var read = Assert.Single(reopened.OpenPriorities(PriorityList.Today));
        Assert.Equal("Send the report", read.Title);
        Assert.Equal(PriorityLevel.High, read.Level);
        Assert.Equal(Time.At("2026-10-12T16:00:00"), read.DueAt);
        Assert.Equal(["Check the numbers"], reopened.Subtasks(read.Id).Select(s => s.Title));
        Assert.Equal("Call Ana", reopened.NoteBody(NoteScope.Day));
        Assert.Equal(PanelTab.Notes, reopened.Value(AppStateKeys.OpenTab));
        Assert.Equal([Created, Edited], reopened.Types(read.Id));
    }
}
