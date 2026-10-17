using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.Repeat;

public sealed class RepeatStoreTests : IDisposable
{
    private readonly TestStore _test = new(new TestClock("2026-10-12T09:00:00"));
    private AppStore Store => _test.Store;
    private TestClock Clock => _test.Clock;

    public void Dispose() => _test.Dispose();

    private void NextDay(string at = "2026-10-13T07:00:00") => Clock.Set(at);

    private List<long> OpenCopiesBySeries() => _test.Rows<long>(
        "SELECT COUNT(*) FROM priority WHERE done_at IS NULL GROUP BY COALESCE(repeat_series_id, id) ORDER BY 1 DESC");

    [Fact]
    public void TheNextDayAddsOneOpenCopyToHoy()
    {
        Store.Add("Otra", PriorityList.Week);
        var source = Store.AddDaily("Meditar", level: PriorityLevel.High, due: "2026-10-12T18:30:00", note: "Diez minutos.");
        var first = Store.AddSubtask(source.Id, "Respirar")!;
        Store.AddSubtask(source.Id, "Estirar");
        Store.ToggleSubtask(first.Id);
        Clock.Set("2026-10-12T21:00:00");
        Store.MarkDone(source.Id);
        var sourceEvents = Store.Types(source.Id);

        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());

        Assert.NotEqual(source.Id, copy.Id);
        Assert.Equal("Meditar", copy.Title);
        Assert.Equal(PriorityLevel.High, copy.Level);
        Assert.Equal("Diez minutos.", copy.Note);
        Assert.Equal(PriorityList.Today, copy.List);
        Assert.Equal(RepeatRule.Daily, copy.RepeatRule);
        Assert.Equal(source.Id, copy.RepeatSeriesId);
        Assert.Equal(source.Id, copy.SeriesId);
        Assert.Equal(Time.At("2026-10-13T18:30:00"), copy.DueAt);
        Assert.Null(copy.DoneAt);
        Assert.Equal(Time.At("2026-10-13T07:00:00"), copy.CreatedAt);
        Assert.Equal(3, copy.Position);
        Assert.Equal(copy, Store.Find(copy.Id));

        Assert.Equal([copy.Id], Store.OpenPriorities(PriorityList.Today).Ids());
        Assert.Equal([source.Id], Store.DonePriorities(PriorityList.Today).Ids());
        Assert.Equal(1, Store.OpenCount(PriorityList.Week));

        var copied = Store.Subtasks(copy.Id);
        Assert.Equal(["Respirar", "Estirar"], copied.Select(s => s.Title));
        Assert.Equal([false, false], copied.Select(s => s.IsDone));
        Assert.Equal([1, 2], copied.Select(s => s.Position));
        Assert.Empty(copied.Select(s => s.Id).Intersect(Store.Subtasks(source.Id).Select(s => s.Id)));
        Assert.Equal([true, false], Store.Subtasks(source.Id).Select(s => s.IsDone));

        Assert.Equal([Created], Store.Types(copy.Id));
        Assert.Equal([Time.At("2026-10-13T07:00:00")], Store.Events(copy.Id).Select(e => e.At));
        Assert.Equal(sourceEvents, Store.Types(source.Id));
        Assert.Equal(Time.At("2026-10-12T21:00:00"), Store.Find(source.Id)!.DoneAt);
        Assert.Equal(
            [$"2026-10-13T18:30:00 2026-10-13T07:00:00 daily {source.Id}"],
            _test.Rows<string>($"SELECT due_at || ' ' || created_at || ' ' || repeat_rule || ' ' || repeat_series_id FROM priority WHERE id = '{copy.Id}'"));
    }

    [Fact]
    public void TwoRunsInARowAddNothingTheSecondTime()
    {
        Store.DoneDaily();
        Store.DoneDaily("Leer");
        NextDay();

        Assert.Equal(["Meditar", "Leer"], Store.AddRepeatCopies().Titles());
        var changes = _test.Changes;
        Assert.Empty(Store.AddRepeatCopies());
        Clock.Advance(600);
        Assert.Empty(Store.AddRepeatCopies());

        Assert.Equal(changes, _test.Changes);
        Assert.Equal(2, Store.OpenPriorities(PriorityList.Today).Count);
        Assert.Equal([4L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
        Assert.Equal([4L], _test.Rows<long>("SELECT COUNT(*) FROM priority_event WHERE type = 'created'"));
        Assert.Equal([1L, 1L], OpenCopiesBySeries());
    }

    [Fact]
    public void APriorityDoneTodayGetsItsCopyOnTheNextDayOnly()
    {
        Store.DoneDaily();
        Assert.Empty(Store.AddRepeatCopies());
        Clock.Set("2026-10-12T23:59:59");
        Assert.Empty(Store.AddRepeatCopies());
        Clock.Set("2026-10-13T00:00:00");
        Assert.Single(Store.AddRepeatCopies());
    }

    [Fact]
    public void SeveralMissedDaysAddOneCopyForToday()
    {
        Store.DoneDaily(due: "2026-10-12T08:15:00");
        NextDay("2026-10-19T10:00:00");

        var copy = Assert.Single(Store.AddRepeatCopies());

        Assert.Equal(Time.At("2026-10-19T08:15:00"), copy.DueAt);
        Assert.Equal([2L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void ACopyThatIsStillOpenOnTheNextDayStaysAlone()
    {
        Store.DoneDaily();
        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());

        NextDay("2026-10-14T07:00:00");
        Assert.Empty(Store.AddRepeatCopies());
        NextDay("2026-10-20T07:00:00");
        Assert.Empty(Store.AddRepeatCopies());
        Assert.Equal([copy.Id], Store.OpenPriorities(PriorityList.Today).Ids());
    }

    [Fact]
    public void TheRuleOffOnTheOpenCopyEndsTheSeriesWhenTheCopyIsDone()
    {
        Store.DoneDaily();
        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());

        Store.SetRepeat(copy.Id, RepeatRule.None);
        Store.MarkDone(copy.Id);
        NextDay("2026-10-14T07:00:00");

        Assert.Empty(Store.AddRepeatCopies());
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
    }

    [Fact]
    public void TheRuleOffOnThePriorityDoneLastEndsTheSeries()
    {
        var source = Store.DoneDaily();
        Store.SetRepeat(source.Id, RepeatRule.None);
        NextDay();

        Assert.Empty(Store.AddRepeatCopies());

        Store.SetRepeat(source.Id, RepeatRule.Daily);
        Assert.Single(Store.AddRepeatCopies());
    }

    [Fact]
    public void ADailyPriorityOfSemanaGetsItsCopyInHoy()
    {
        var source = Store.DoneDaily(list: PriorityList.Week);
        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());

        Assert.Equal(PriorityList.Today, copy.List);
        Assert.Equal([source.Id], Store.DonePriorities(PriorityList.Week).Ids());
        Assert.Empty(Store.OpenPriorities(PriorityList.Week));

        Store.MoveToList(copy.Id, PriorityList.Week);
        Store.MarkDone(copy.Id);
        NextDay("2026-10-14T07:00:00");
        var third = Assert.Single(Store.AddRepeatCopies());
        Assert.Equal(PriorityList.Today, third.List);
        Assert.Equal(source.Id, third.SeriesId);
    }

    [Fact]
    public void EachCopyOfASeriesHasTheSameSeriesAndTheLastContent()
    {
        var source = Store.DoneDaily();
        Priority last = source;
        for (var day = 13; day <= 16; day++)
        {
            NextDay($"2026-10-{day}T07:00:00");
            var copy = Assert.Single(Store.AddRepeatCopies());
            Assert.Empty(Store.AddRepeatCopies());
            Assert.Equal([1L], OpenCopiesBySeries());
            Assert.Equal(source.Id, copy.SeriesId);
            Store.EditTitle(copy.Id, $"Meditar {day}");
            last = Store.MarkDone(copy.Id);
        }
        Assert.Equal("Meditar 16", last.Title);
        NextDay("2026-10-17T07:00:00");
        Assert.Equal(["Meditar 16"], Store.AddRepeatCopies().Titles());
        Assert.Equal([1L], _test.Rows<long>("SELECT COUNT(DISTINCT COALESCE(repeat_series_id, id)) FROM priority"));
        Assert.Equal([6L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void APriorityWrittenByAnotherProgramWithNoSeriesStartsItsSeries()
    {
        _test.Execute("""
            INSERT INTO priority (id, title, level, list, done_at, position, created_at, updated_at, repeat_rule)
            VALUES ('p1', 'From sqlite3', 'low', 'week', '2026-10-11T22:00:00', 1, '2026-10-11T09:00:00', '2026-10-11T22:00:00', 'daily')
            """);

        var copy = Assert.Single(Store.AddRepeatCopies());

        Assert.Equal("From sqlite3", copy.Title);
        Assert.Equal("p1", copy.RepeatSeriesId);
        Assert.Null(copy.DueAt);
        Assert.Equal(["From sqlite3"], Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Empty(Store.AddRepeatCopies());
    }

    [Fact]
    public void ARestoreReplacesTheNewerCopyThatThePersonDidNotChange()
    {
        var source = Store.AddDaily(due: "2026-10-12T23:00:00");
        Store.AddSubtask(source.Id, "Respirar");
        Store.MarkDone(source.Id);
        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());
        Store.SaveAlerts([new PriorityAlert("a1", copy.Id, AlertKind.AtDue, Time.At("2026-10-13T23:00:00"), AlertStatus.Scheduled)]);

        var restored = Store.Restore(source.Id);

        Assert.Null(restored.DoneAt);
        Assert.Equal(RepeatRule.Daily, restored.RepeatRule);
        Assert.Equal(source.Id, restored.SeriesId);
        Assert.Null(Store.Find(copy.Id));
        Assert.Equal([source.Id], Store.OpenPriorities(PriorityList.Today).Ids());
        Assert.Empty(Store.Subtasks(copy.Id));
        Assert.Equal([1L], _test.Rows<long>("SELECT COUNT(*) FROM subtask"));
        Assert.Empty(Store.Alerts());
        Assert.Equal([1L], OpenCopiesBySeries());
        Assert.Equal(Restored, Store.Types(source.Id)[^1]);
        Assert.Empty(Store.AddRepeatCopies());
    }

    [Fact]
    public void ARestoreKeepsTheNewerCopyThatThePersonChanged()
    {
        var source = Store.DoneDaily();
        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());
        Store.AddSubtask(copy.Id, "Trabajo de hoy");

        var restored = Store.Restore(source.Id);

        Assert.Null(restored.DoneAt);
        Assert.Equal(RepeatRule.None, restored.RepeatRule);
        Assert.NotEqual(copy.SeriesId, restored.SeriesId);
        Assert.Equal(RepeatRule.Daily, Store.Find(copy.Id)!.RepeatRule);
        Assert.Equal(["Trabajo de hoy"], Store.Subtasks(copy.Id).Select(s => s.Title));
        Assert.Equal(new[] { source.Id, copy.Id }.Order(), Store.OpenPriorities(PriorityList.Today).Ids().Order());
        Assert.Equal([1L, 1L], OpenCopiesBySeries());

        Store.MarkDone(restored.Id);
        Store.MarkDone(copy.Id);
        NextDay("2026-10-14T07:00:00");
        Assert.Equal([copy.SeriesId], Store.AddRepeatCopies().Select(p => p.SeriesId));
        Assert.Equal([1L], OpenCopiesBySeries());
    }

    [Theory]
    [InlineData(Edited)]
    [InlineData(Moved)]
    [InlineData(SubtaskDone)]
    public void EachChangeOfThePersonKeepsTheNewerCopy(PriorityEventType change)
    {
        var source = Store.AddDaily();
        Store.AddSubtask(source.Id, "Respirar");
        Store.MarkDone(source.Id);
        NextDay();
        var copy = Assert.Single(Store.AddRepeatCopies());
        switch (change)
        {
            case Moved:
                Store.MoveToList(copy.Id, PriorityList.Week);
                break;
            case SubtaskDone:
                Store.ToggleSubtask(Store.Subtasks(copy.Id)[0].Id);
                break;
            default:
                Store.SetNote(copy.Id, "Nota de hoy");
                break;
        }
        Assert.Equal([Created, change], Store.Types(copy.Id));

        Store.Restore(source.Id);

        Assert.NotNull(Store.Find(copy.Id));
        Assert.Equal([1L, 1L], OpenCopiesBySeries());
    }

    [Fact]
    public void ARestoreWithNoOpenCopyChangesNoRuleAndNoSeries()
    {
        var source = Store.DoneDaily();
        var plain = Store.Add("Una vez");
        Store.MarkDone(plain.Id);

        var restored = Store.Restore(source.Id);
        var restoredPlain = Store.Restore(plain.Id);

        Assert.Equal(RepeatRule.Daily, restored.RepeatRule);
        Assert.Null(restored.RepeatSeriesId);
        Assert.Equal(RepeatRule.None, restoredPlain.RepeatRule);
        Assert.Null(restoredPlain.RepeatSeriesId);
        Assert.Equal([2L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
        NextDay();
        Assert.Empty(Store.AddRepeatCopies());
    }

    [Fact]
    public void ARestoredPriorityThatIsDoneAgainTodayGetsItsCopyOnTheNextDay()
    {
        var source = Store.DoneDaily();
        NextDay();
        Store.AddRepeatCopies();
        Store.Restore(source.Id);
        Store.EditTitle(source.Id, "Meditar mejor");
        Store.MarkDone(source.Id);

        Assert.Empty(Store.AddRepeatCopies());
        NextDay("2026-10-14T07:00:00");
        Assert.Equal(["Meditar mejor"], Store.AddRepeatCopies().Titles());
    }

    [Fact]
    public void TheDeleteOfTheOpenCopyEndsTheSeries()
    {
        var source = Store.DoneDaily();
        NextDay();
        var second = Assert.Single(Store.AddRepeatCopies());
        Store.MarkDone(second.Id);
        NextDay("2026-10-14T07:00:00");
        var third = Assert.Single(Store.AddRepeatCopies());
        var eventsBefore = Store.Types(source.Id);

        Clock.Advance(30);
        Store.Delete(third.Id);

        Assert.Empty(Store.AddRepeatCopies());
        Assert.Equal(RepeatRule.None, Store.Find(source.Id)!.RepeatRule);
        Assert.Equal(RepeatRule.None, Store.Find(second.Id)!.RepeatRule);
        Assert.Equal([.. eventsBefore, Edited], Store.Types(source.Id));
        Assert.Equal(Edited, Store.Types(second.Id)[^1]);
        Assert.Equal(Time.At("2026-10-14T07:30:00"), Store.Events(second.Id)[^1].At);
        NextDay("2026-10-15T07:00:00");
        Assert.Empty(Store.AddRepeatCopies());
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
    }

    [Fact]
    public void TheDeleteOfAnOpenPriorityWithNoSeriesChangesNoOtherRow()
    {
        var daily = Store.DoneDaily();
        var plain = Store.Add("Una vez");

        Store.Delete(plain.Id);

        Assert.Equal(RepeatRule.Daily, Store.Find(daily.Id)!.RepeatRule);
        Assert.Equal([Created, Edited, Done], Store.Types(daily.Id));
    }

    [Fact]
    public void TheDeleteOfADoneCopyLetsTheSeriesGoOnFromTheLastCopyLeft()
    {
        var source = Store.DoneDaily();
        NextDay();
        var second = Assert.Single(Store.AddRepeatCopies());
        Store.EditTitle(second.Id, "Meditar dos");
        Store.MarkDone(second.Id);

        NextDay("2026-10-14T07:00:00");
        Store.Delete(second.Id);
        var third = Assert.Single(Store.AddRepeatCopies());

        Assert.Equal("Meditar", third.Title);
        Assert.Equal(source.Id, third.SeriesId);
        Assert.Equal(RepeatRule.Daily, Store.Find(source.Id)!.RepeatRule);
    }

    [Fact]
    public void TheDeleteOfTheFirstPriorityKeepsTheSeriesOfItsCopies()
    {
        var source = Store.DoneDaily();
        NextDay();
        var second = Assert.Single(Store.AddRepeatCopies());
        Store.MarkDone(second.Id);
        Store.Delete(source.Id);

        NextDay("2026-10-14T07:00:00");
        Assert.Equal([source.Id], Store.AddRepeatCopies().Select(p => p.SeriesId));
        Assert.Equal([1L], OpenCopiesBySeries());
    }

    [Fact]
    public void TheDeleteOfTheOnlyPriorityLeavesNoSeries()
    {
        var source = Store.DoneDaily();
        Store.Delete(source.Id);
        NextDay();

        Assert.Empty(Store.AddRepeatCopies());
        Assert.Equal([0L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void SetRepeatChangesTheRuleAndWritesEditedOnlyOnAChange()
    {
        var added = Store.Add("Meditar");
        Assert.Equal(RepeatRule.None, added.RepeatRule);
        Assert.Null(added.RepeatSeriesId);

        Clock.Advance(5);
        var daily = Store.SetRepeat(added.Id, RepeatRule.Daily);

        Assert.Equal(RepeatRule.Daily, daily.RepeatRule);
        Assert.Null(daily.RepeatSeriesId);
        Assert.Equal(Time.At("2026-10-12T09:05:00"), daily.UpdatedAt);
        Assert.Equal([Created, Edited], Store.Types(added.Id));
        Assert.Equal(["daily"], _test.Rows<string>("SELECT repeat_rule FROM priority"));

        Store.SetRepeat(added.Id, RepeatRule.Daily);
        Assert.Equal([Created, Edited], Store.Types(added.Id));
        Store.SetRepeat(added.Id, RepeatRule.None);
        Assert.Equal([Created, Edited, Edited], Store.Types(added.Id));
    }
}
