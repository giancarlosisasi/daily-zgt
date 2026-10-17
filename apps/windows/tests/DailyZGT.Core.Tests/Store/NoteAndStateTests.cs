using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.Store;

public sealed class NoteAndStateTests : IDisposable
{
    private readonly TestStore _test = new();
    private AppStore Store => _test.Store;
    private TestClock Clock => _test.Clock;

    public void Dispose() => _test.Dispose();

    [Fact]
    public void ThePeriodsComeFromTheClock()
    {
        Assert.Equal("2026-10-12", Store.Period(NoteScope.Day));
        Assert.Equal("2026-W42", Store.Period(NoteScope.Week));
        Clock.Set("2026-10-19T00:00:00");
        Assert.Equal("2026-10-19", Store.Period(NoteScope.Day));
        Assert.Equal("2026-W43", Store.Period(NoteScope.Week));
    }

    [Fact]
    public void SaveNoteInsertsThenUpdatesOneRow()
    {
        Assert.Equal("", Store.NoteBody(NoteScope.Day));

        Store.SaveNote(NoteScope.Day, "Call Ana");
        Clock.Advance(15);
        Store.SaveNote(NoteScope.Day, "Call Ana at 15:00");

        Assert.Equal("Call Ana at 15:00", Store.NoteBody(NoteScope.Day));
        Assert.Equal(["Call Ana at 15:00"], _test.Rows<string>("SELECT body FROM note"));
        Assert.Equal(["2026-10-12"], _test.Rows<string>("SELECT period FROM note"));
        Assert.Equal(["2026-10-12T09:15:00"], _test.Rows<string>("SELECT updated_at FROM note"));
    }

    [Fact]
    public void EachDayAndEachWeekKeepsItsNote()
    {
        Store.SaveNote(NoteScope.Day, "Monday");
        Store.SaveNote(NoteScope.Week, "Week 42");
        Clock.Set("2026-10-13T08:00:00");
        Store.SaveNote(NoteScope.Day, "Tuesday");

        Assert.Equal("Tuesday", Store.NoteBody(NoteScope.Day));
        Assert.Equal("Monday", Store.NoteBody(NoteScope.Day, "2026-10-12"));
        Assert.Equal("Week 42", Store.NoteBody(NoteScope.Week));
        Assert.Equal("", Store.NoteBody(NoteScope.Week, "2026-W43"));
        Assert.Equal([3L], _test.Rows<long>("SELECT COUNT(*) FROM note"));
    }

    [Fact]
    public void ANoteSavedForAnEarlierPeriodGoesToThatPeriod()
    {
        Clock.Set("2026-10-13T00:00:10");
        Store.SaveNote(NoteScope.Day, "Late edit of Monday", "2026-10-12");
        Assert.Equal("Late edit of Monday", Store.NoteBody(NoteScope.Day, "2026-10-12"));
        Assert.Equal("", Store.NoteBody(NoteScope.Day));
    }

    [Fact]
    public void ClearingANoteThatWasNeverSavedSavesNothing()
    {
        var changes = _test.Changes;
        Store.SaveNote(NoteScope.Day, "");
        Assert.Empty(_test.Rows<string>("SELECT body FROM note"));
        Assert.Equal(changes, _test.Changes);
    }

    [Fact]
    public void ClearingASavedNoteLeavesItEmpty()
    {
        Store.SaveNote(NoteScope.Day, "Call Ana");
        Store.SaveNote(NoteScope.Day, "");
        Assert.Equal([""], _test.Rows<string>("SELECT body FROM note"));
        Assert.Equal("", Store.NoteBody(NoteScope.Day));
    }

    [Fact]
    public void AppStateGivesTheDefaultThenTheSavedValue()
    {
        var limit = new AppStateKey<int?>("custom_limit", null);
        Assert.Equal(PanelTab.Priorities, Store.Value(AppStateKeys.OpenTab));
        Assert.Equal(PriorityList.Today, Store.Value(AppStateKeys.OpenScope));
        Assert.False(Store.Value(AppStateKeys.DoneOpen));
        Assert.False(Store.Value(AppStateKeys.TodayLimit));
        Assert.True(Store.Value(AppStateKeys.TrayTitle));
        Assert.Null(Store.Value(limit));

        Store.SetValue(AppStateKeys.OpenTab, PanelTab.Notes);
        Store.SetValue(AppStateKeys.OpenScope, PriorityList.Week);
        Store.SetValue(AppStateKeys.DoneOpen, true);
        Store.SetValue(limit, 5);
        Store.SetValue(AppStateKeys.DoneOpen, false);

        Assert.Equal(PanelTab.Notes, Store.Value(AppStateKeys.OpenTab));
        Assert.Equal(PriorityList.Week, Store.Value(AppStateKeys.OpenScope));
        Assert.False(Store.Value(AppStateKeys.DoneOpen));
        Assert.Equal(5, Store.Value(limit));
        Assert.Equal(
            ["custom_limit=5", "done_open=false", "open_scope=\"week\"", "open_tab=\"notes\""],
            _test.Rows<string>("SELECT key || '=' || value FROM app_state ORDER BY key"));
    }

    [Fact]
    public void AppStateWrittenByTheMacOSAppReadsBack()
    {
        _test.Execute("""
            INSERT INTO app_state (key, value) VALUES
                ('open_tab', '"notes"'), ('open_scope', '"week"'), ('done_open', 'true'),
                ('today_limit', 'true'), ('menu_bar_title', 'false')
            """);
        Store.CheckForExternalChanges();

        Assert.Equal(PanelTab.Notes, Store.Value(AppStateKeys.OpenTab));
        Assert.Equal(PriorityList.Week, Store.Value(AppStateKeys.OpenScope));
        Assert.True(Store.Value(AppStateKeys.DoneOpen));
        Assert.True(Store.TodayLimitIsOn);
        Assert.False(Store.Value(AppStateKeys.TrayTitle));
    }

    [Fact]
    public void AppStateWithUnreadableTextGivesTheDefault()
    {
        _test.Execute("""
            INSERT INTO app_state (key, value) VALUES
                ('today_limit', 'not json'), ('open_scope', '"month"'), ('open_tab', '1'), ('menu_bar_title', 'null')
            """);
        Store.CheckForExternalChanges();

        Assert.Equal("not json", Store.Snapshot.AppState["today_limit"]);
        Assert.False(Store.TodayLimitIsOn);
        Assert.Equal(PriorityList.Today, Store.Value(AppStateKeys.OpenScope));
        Assert.Equal(PanelTab.Priorities, Store.Value(AppStateKeys.OpenTab));
        Assert.True(Store.Value(AppStateKeys.TrayTitle));
    }
}
