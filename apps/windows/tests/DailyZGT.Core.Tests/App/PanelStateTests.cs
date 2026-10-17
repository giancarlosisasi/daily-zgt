using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.App;

public sealed class PanelStateTests : IDisposable
{
    private readonly AppHarness _app = new();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void StartsOnPrioritiesAndTodayWithDoneClosed()
    {
        var panel = _app.Panel();

        Assert.Equal(PanelTab.Priorities, panel.Tab);
        Assert.Equal(PriorityList.Today, panel.Scope);
        Assert.False(panel.IsDoneOpen);
        Assert.IsType<PanelPage.Browse>(panel.Page);
    }

    [Fact]
    public void TabScopeAndDoneAreSavedInAppStateAsTheMacAppWritesThem()
    {
        var panel = _app.Panel();

        panel.SelectTab(PanelTab.Notes);
        panel.SelectScope(PriorityList.Week);
        panel.ToggleDone();

        Assert.Equal(["\"notes\""], _app.Rows<string>("SELECT value FROM app_state WHERE key = 'open_tab'"));
        Assert.Equal(["\"week\""], _app.Rows<string>("SELECT value FROM app_state WHERE key = 'open_scope'"));
        Assert.Equal(["true"], _app.Rows<string>("SELECT value FROM app_state WHERE key = 'done_open'"));
        Assert.False(panel.SaveFailed);
    }

    [Fact]
    public void ANewStoreOnTheSameFileRestoresTheTabTheScopeAndDone()
    {
        var first = _app.Panel();
        first.SelectTab(PanelTab.Notes);
        first.SelectScope(PriorityList.Week);
        first.ToggleDone();

        var second = _app.Panel(_app.OpenAnotherStore());

        Assert.Equal(PanelTab.Notes, second.Tab);
        Assert.Equal(PriorityList.Week, second.Scope);
        Assert.True(second.IsDoneOpen);
    }

    [Fact]
    public void SelectingTheSameValueWritesNothing()
    {
        var panel = _app.Panel();

        panel.SelectTab(PanelTab.Priorities);
        panel.SelectScope(PriorityList.Today);

        Assert.Empty(_app.Rows<string>("SELECT key FROM app_state"));
    }

    [Fact]
    public void TheScopeMapsToTheNoteScope()
    {
        Assert.Equal(NoteScope.Day, PriorityList.Today.NoteScope());
        Assert.Equal(NoteScope.Week, PriorityList.Week.NoteScope());
    }

    [Fact]
    public void TheNotesFollowTheScope()
    {
        _app.Store.SaveNote(NoteScope.Week, "Week text");
        var panel = _app.Panel();

        panel.SelectScope(PriorityList.Week);

        Assert.Equal(NoteScope.Week, panel.Notes.Scope);
        Assert.Equal("Week text", panel.Notes.Text);
    }

    [Fact]
    public void TheFormAddsToTheOpenScope()
    {
        var panel = _app.Panel();
        panel.SelectScope(PriorityList.Week);
        panel.Form.Open();
        panel.Form.Title = "For the week";

        panel.Form.Submit();

        Assert.Equal(["For the week"], _app.Store.OpenPriorities(PriorityList.Week).Titles());
    }

    [Fact]
    public void TheTodayLimitAndTheTrayTitleSettingsAreSavedAndRead()
    {
        var panel = _app.Panel();
        Assert.False(panel.TodayLimitIsOn);
        Assert.True(panel.TrayTitleIsOn);

        panel.TodayLimitIsOn = true;
        panel.TrayTitleIsOn = false;

        Assert.Equal(["true"], _app.Rows<string>("SELECT value FROM app_state WHERE key = 'today_limit'"));
        Assert.Equal(["false"], _app.Rows<string>("SELECT value FROM app_state WHERE key = 'menu_bar_title'"));
        Assert.True(_app.Store.TodayLimitIsOn);
        Assert.True(panel.TodayLimitIsOn);
        Assert.False(panel.TrayTitleIsOn);
    }

    [Fact]
    public void AChangeFromOutsideRaisesTheSettingProperties()
    {
        var panel = _app.Panel();
        var raised = new List<string?>();
        panel.PropertyChanged += (_, e) => raised.Add(e.PropertyName);

        _app.Execute("INSERT INTO app_state (key, value) VALUES ('today_limit', 'true')");
        _app.Store.CheckForExternalChanges();

        Assert.Contains(nameof(PanelState.TodayLimitIsOn), raised);
        Assert.True(panel.TodayLimitIsOn);
    }

    [Fact]
    public void AFailedWriteOfAValueRaisesTheFlag()
    {
        var panel = _app.Panel();
        _app.Execute("DROP TABLE app_state");

        panel.SelectTab(PanelTab.Notes);

        Assert.True(panel.SaveFailed);
        Assert.Equal(PanelTab.Notes, panel.Tab);
    }
}

public sealed class PanelHistoryTests : IDisposable
{
    private readonly AppHarness _app = new();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void OpeningTheHistoryShowsItOnThePrioritiesTab()
    {
        var panel = _app.Panel();
        panel.SelectTab(PanelTab.Notes);

        panel.OpenHistory();

        Assert.IsType<PanelPage.History>(panel.Page);
        Assert.Equal(PanelTab.Priorities, panel.Tab);
    }

    [Fact]
    public void TheBackButtonAndAScopeChangeCloseTheHistory()
    {
        var panel = _app.Panel();
        panel.OpenHistory();
        panel.CloseHistory();
        Assert.IsType<PanelPage.Browse>(panel.Page);

        panel.OpenHistory();
        panel.SelectScope(PriorityList.Week);
        Assert.IsType<PanelPage.Browse>(panel.Page);
    }

    [Fact]
    public void TheGearOverTheHistoryOpensTheSettings()
    {
        var panel = _app.Panel();
        panel.OpenHistory();

        panel.ToggleSettings();

        Assert.IsType<PanelPage.Settings>(panel.Page);
    }

    [Fact]
    public void TheHistoryIsNotKeptInTheDatabase()
    {
        var panel = _app.Panel();
        panel.OpenHistory();

        Assert.IsType<PanelPage.Browse>(_app.Panel(_app.OpenAnotherStore()).Page);
    }
}

public sealed class PanelDetailNavigationTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PanelState _panel;

    public PanelDetailNavigationTests() => _panel = _app.Panel();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void NoPriorityIsOpenAtStart()
    {
        Assert.Null(_panel.Detail);
    }

    [Fact]
    public void OpeningAPriorityShowsItAndSetsTheTabAndTheList()
    {
        var week = _app.Store.Add("Week item", PriorityList.Week);
        _panel.SelectTab(PanelTab.Notes);

        _panel.OpenDetail(week.Id);

        Assert.Equal(week.Id, _panel.Detail?.Id);
        Assert.Equal(PanelTab.Priorities, _panel.Tab);
        Assert.Equal(PriorityList.Week, _panel.Scope);
    }

    [Fact]
    public void BackReturnsToTheList()
    {
        var first = _app.Store.Add("First");

        _panel.OpenDetail(first.Id);
        _panel.CloseDetail();

        Assert.Null(_panel.Detail);
        Assert.IsType<PanelPage.Browse>(_panel.Page);
        Assert.Equal(PriorityList.Today, _panel.Scope);
        Assert.NotNull(_app.Store.Find(first.Id));
    }

    [Fact]
    public void OpeningAnUnknownOrDoneIdDoesNothing()
    {
        var done = _app.Store.MarkDone(_app.Store.Add("Done").Id);

        _panel.OpenDetail("missing");
        Assert.Null(_panel.Detail);

        _panel.OpenDetail(done.Id);
        Assert.Null(_panel.Detail);
    }

    [Fact]
    public void OpeningAnotherPriorityReplacesTheOpenOne()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");

        _panel.OpenDetail(first.Id);
        _panel.OpenDetail(second.Id);

        Assert.Equal(second.Id, _panel.Detail?.Id);
    }

    [Fact]
    public void ATabClickClosesTheDetailEvenOnTheSameTab()
    {
        var first = _app.Store.Add("First");

        _panel.OpenDetail(first.Id);
        _panel.SelectTab(PanelTab.Priorities);
        Assert.Null(_panel.Detail);

        _panel.OpenDetail(first.Id);
        _panel.SelectTab(PanelTab.Notes);
        Assert.Null(_panel.Detail);
        Assert.Equal(PanelTab.Notes, _panel.Tab);
    }

    [Fact]
    public void TheDetailFollowsAMoveToTheOtherList()
    {
        var first = _app.Store.Add("First");
        _panel.OpenDetail(first.Id);

        _panel.Detail!.SetList(PriorityList.Week);

        Assert.Equal(first.Id, _panel.Detail?.Id);
        Assert.Equal(PriorityList.Week, _panel.Detail?.Priority.List);
        Assert.Equal(PriorityList.Week, _panel.Scope);
    }

    [Fact]
    public void ADeletedPriorityReturnsToTheList()
    {
        var first = _app.Store.Add("First");
        _panel.OpenDetail(first.Id);

        _panel.Flow.Delete(first.Id);

        Assert.Null(_panel.Detail);
        Assert.IsType<PanelPage.Browse>(_panel.Page);
    }

    [Fact]
    public void APriorityDoneByAnotherWriterReturnsToTheListAndDoesNotComeBack()
    {
        var first = _app.Store.Add("First");
        _panel.OpenDetail(first.Id);
        var other = _app.OpenAnotherStore();

        other.MarkDone(first.Id);
        _app.Store.CheckForExternalChanges();
        Assert.Null(_panel.Detail);

        _app.Store.Restore(first.Id);
        Assert.Null(_panel.Detail);
    }

    [Fact]
    public void AChangeThatKeepsThePriorityOpenRefreshesTheDetail()
    {
        var first = _app.Store.Add("First");
        _panel.OpenDetail(first.Id);

        _app.Store.EditTitle(first.Id, "Renamed");

        Assert.Equal("Renamed", _panel.Detail?.Priority.Title);
        Assert.Equal("Renamed", _panel.Detail?.TitleDraft);
    }

    [Fact]
    public void OpeningAndClosingClearAnOpenConfirmation()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");

        _panel.Flow.ToggleConfirmation(second.Id);
        _panel.OpenDetail(first.Id);
        Assert.Null(_panel.Flow.ConfirmingId);

        _panel.Flow.ToggleConfirmation(first.Id);
        _panel.CloseDetail();
        Assert.Null(_panel.Flow.ConfirmingId);
    }

    [Fact]
    public void DoneFromTheDetailAsksFirstThenReturnsToTheListWithTheUndo()
    {
        var first = _app.Store.Add("Send the report");
        _panel.OpenDetail(first.Id);

        _panel.Flow.ToggleConfirmation(first.Id);
        Assert.Equal(RowPhase.Confirming, _panel.Flow.PhaseOf(first.Id));
        Assert.False(_app.Store.Find(first.Id)!.IsDone);

        _panel.Flow.CancelConfirmation();
        Assert.Equal(first.Id, _panel.Detail?.Id);

        _panel.Flow.ToggleConfirmation(first.Id);
        _panel.Flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        Assert.True(_app.Store.Find(first.Id)!.IsDone);
        Assert.Null(_panel.Detail);
        Assert.Equal("Send the report", _panel.Flow.Undo?.Title);
        Assert.True(_panel.UndoBarVisible);
        Assert.Equal([PriorityEventType.Created, PriorityEventType.Done], _app.Store.Types(first.Id));
    }

    [Fact]
    public void ClosingTheDetailSavesTheNoteAtOnce()
    {
        var first = _app.Store.Add("First");
        _panel.OpenDetail(first.Id);
        _panel.Detail!.Note.Edit("Typed just now");

        _panel.CloseDetail();

        Assert.Equal("Typed just now", _app.Store.Find(first.Id)!.Note);
    }

    [Fact]
    public void TheSubtasksOfARowStayOpenAcrossTheDetail()
    {
        var first = _app.Store.Add("First");
        _panel.Flow.ToggleSubtasks(first.Id);

        _panel.OpenDetail(first.Id);
        _panel.CloseDetail();
        _panel.SelectTab(PanelTab.Notes);
        _panel.SelectTab(PanelTab.Priorities);

        Assert.True(_panel.Flow.IsExpanded(first.Id));
    }
}

public sealed class PanelAlertNavigationTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PanelState _panel;

    public PanelAlertNavigationTests() => _panel = _app.Panel();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void ShowingAPriorityInTheListSelectsItsListAndHighlightsIt()
    {
        var week = _app.Store.Add("Week item", PriorityList.Week);
        _panel.SelectTab(PanelTab.Notes);

        _panel.ShowInList(week.Id);

        Assert.Equal(PanelTab.Priorities, _panel.Tab);
        Assert.Equal(PriorityList.Week, _panel.Scope);
        Assert.Null(_panel.Detail);
        Assert.Equal(week.Id, _panel.Flow.HighlightedId);
        Assert.Equal(week.Id, _panel.Flow.ScrollTargetId);

        _app.Advance(PriorityFlow.HighlightLifetime);
        Assert.Null(_panel.Flow.HighlightedId);
    }

    [Fact]
    public void ShowingAPriorityInTheListClosesTheDetailOfAnotherPriority()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _panel.OpenDetail(first.Id);

        _panel.ShowInList(second.Id);

        Assert.Null(_panel.Detail);
        Assert.Equal(second.Id, _panel.Flow.HighlightedId);
    }

    [Fact]
    public void ShowingNoPriorityOpensTheListOfToday()
    {
        _panel.SelectTab(PanelTab.Notes);
        _panel.SelectScope(PriorityList.Week);

        _panel.ShowInList(null);

        Assert.Equal(PanelTab.Priorities, _panel.Tab);
        Assert.Equal(PriorityList.Today, _panel.Scope);
        Assert.Null(_panel.Flow.HighlightedId);
    }

    [Fact]
    public void ShowingADoneOrUnknownPriorityHighlightsNothing()
    {
        var done = _app.Store.MarkDone(_app.Store.Add("Done", PriorityList.Week).Id);

        _panel.ShowInList(done.Id);
        _panel.ShowInList("missing");

        Assert.Equal(PriorityList.Today, _panel.Scope);
        Assert.Null(_panel.Flow.HighlightedId);
        Assert.Null(_panel.Flow.ScrollTargetId);
    }

    [Fact]
    public void ShowingAPriorityClosesTheSettingsAndTheHistory()
    {
        var week = _app.Store.Add("Week item", PriorityList.Week);
        _panel.OpenSettings();
        _panel.ShowInList(week.Id);
        Assert.IsType<PanelPage.Browse>(_panel.Page);

        _panel.OpenHistory();
        _panel.ShowInList(week.Id);
        Assert.IsType<PanelPage.Browse>(_panel.Page);
    }
}

public sealed class PanelSettingsNavigationTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PanelState _panel;

    public PanelSettingsNavigationTests() => _panel = _app.Panel();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void TheSettingsAreClosedAtStart()
    {
        Assert.IsNotType<PanelPage.Settings>(_panel.Page);
    }

    [Fact]
    public void OpenAndBackToggleTheSettings()
    {
        _panel.OpenSettings();
        Assert.IsType<PanelPage.Settings>(_panel.Page);

        _panel.CloseSettings();
        Assert.IsType<PanelPage.Browse>(_panel.Page);
    }

    [Fact]
    public void TheGearOpensAndClosesTheSettings()
    {
        _panel.ToggleSettings();
        Assert.IsType<PanelPage.Settings>(_panel.Page);

        _panel.ToggleSettings();
        Assert.IsType<PanelPage.Browse>(_panel.Page);
    }

    [Fact]
    public void OpeningTheSettingsClosesTheDetailAndCancelsItsConfirmation()
    {
        var priority = _app.Store.Add("Mandar el reporte");
        _panel.OpenDetail(priority.Id);
        _panel.Flow.ToggleConfirmation(priority.Id);

        _panel.OpenSettings();

        Assert.IsType<PanelPage.Settings>(_panel.Page);
        Assert.Null(_panel.Detail);
        Assert.Null(_panel.Flow.ConfirmingId);
    }

    [Fact]
    public void OpeningTheDetailClosesTheSettings()
    {
        var priority = _app.Store.Add("Mandar el reporte");
        _panel.OpenSettings();

        _panel.OpenDetail(priority.Id);

        Assert.Equal(priority.Id, _panel.Detail?.Id);
    }

    [Fact]
    public void ATabChangeClosesTheSettings()
    {
        _panel.OpenSettings();

        _panel.SelectTab(PanelTab.Notes);

        Assert.IsType<PanelPage.Browse>(_panel.Page);
        Assert.Equal(PanelTab.Notes, _panel.Tab);
    }

    [Fact]
    public void OpeningTheSettingsReadsTheStartupStateAgainAndClearsItsError()
    {
        _app.StartupService.EnableFails = true;
        _panel.Startup.Set(true);
        Assert.True(_panel.Startup.ChangeFailed);
        _app.StartupService.State = StartupStatus.On;
        Assert.False(_panel.Startup.IsOn);

        _panel.OpenSettings();

        Assert.True(_panel.Startup.IsOn);
        Assert.False(_panel.Startup.ChangeFailed);
    }

    [Fact]
    public void OpeningTheSettingsReadsTheShortcutAgain()
    {
        _app.Hotkey.Current = null;
        Assert.True(_panel.Shortcut.IsSet);

        _panel.OpenSettings();

        Assert.False(_panel.Shortcut.IsSet);
    }

    [Fact]
    public void TheSettingsStateIsNotKeptInTheDatabase()
    {
        _panel.OpenSettings();
        _panel.Startup.Set(true);

        Assert.Empty(_app.Rows<string>("SELECT key FROM app_state"));
    }
}

public sealed class PanelUndoBarTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PanelState _panel;
    private readonly Priority _first;

    public PanelUndoBarTests()
    {
        _panel = _app.Panel();
        _first = _app.Store.Add("Mandar el reporte");
    }

    public void Dispose() => _app.Dispose();

    [Fact]
    public void BothTabsHoldTheSameSlotsOnce()
    {
        foreach (var tab in Enum.GetValues<PanelTab>())
        {
            Assert.Equal(Enum.GetValues<PanelContentSlot>().ToHashSet(), PanelContentSlots.Order(tab).ToHashSet());
            Assert.Equal(Enum.GetValues<PanelContentSlot>().Length, PanelContentSlots.Order(tab).Count);
        }
    }

    [Fact]
    public void TheUndoBarIsUnderTheListAndAboveTheNote()
    {
        Assert.Equal([PanelContentSlot.Main, PanelContentSlot.UndoBar], _panel.ContentSlots);

        _panel.SelectTab(PanelTab.Notes);

        Assert.Equal([PanelContentSlot.UndoBar, PanelContentSlot.Main], _panel.ContentSlots);
    }

    [Fact]
    public void TheUndoBarShowsOnBothTabsAndStaysTheSameAcrossTabSwitches()
    {
        _panel.Flow.ConfirmDone(_first.Id, DoneOrigin.List);
        _app.Advance(_app.Motion.LeaveDelay);
        var token = _panel.Flow.Undo!.Token;
        Assert.True(_panel.UndoBarVisible);

        _panel.SelectTab(PanelTab.Notes);
        Assert.True(_panel.UndoBarVisible);
        Assert.Equal(token, _panel.Flow.Undo?.Token);

        _panel.SelectTab(PanelTab.Priorities);
        Assert.Equal(token, _panel.Flow.Undo?.Token);
    }

    [Fact]
    public void TheUndoBarEndsAfterFiveSecondsOnTheNotesTab()
    {
        _panel.SelectTab(PanelTab.Notes);
        _panel.Flow.ConfirmDone(_first.Id, DoneOrigin.List);
        _app.Advance(_app.Motion.LeaveDelay);
        Assert.True(_panel.UndoBarVisible);

        _app.Advance(PriorityFlow.UndoLifetime);

        Assert.False(_panel.UndoBarVisible);
    }

    [Fact]
    public void UndoFromTheNotesTabRestoresThePriority()
    {
        _panel.SelectTab(PanelTab.Notes);
        _panel.Flow.ConfirmDone(_first.Id, DoneOrigin.Detail);

        _panel.Flow.UndoDone();

        Assert.False(_app.Store.Find(_first.Id)!.IsDone);
        Assert.False(_panel.UndoBarVisible);
    }

    [Fact]
    public void TheUndoBarShowsInTheDetailView()
    {
        var second = _app.Store.Add("Otra");
        _panel.Flow.ConfirmDone(_first.Id, DoneOrigin.Detail);

        _panel.OpenDetail(second.Id);

        Assert.True(_panel.UndoBarVisible);
    }

    [Fact]
    public void TheUndoBarHidesInTheSettingsAndTheHistoryAndItsTimeKeepsRunning()
    {
        _panel.Flow.ConfirmDone(_first.Id, DoneOrigin.Detail);
        var raised = new List<string?>();
        _panel.PropertyChanged += (_, e) => raised.Add(e.PropertyName);

        _panel.OpenSettings();
        Assert.False(_panel.UndoBarVisible);
        Assert.Contains(nameof(PanelState.UndoBarVisible), raised);
        _panel.CloseSettings();
        Assert.True(_panel.UndoBarVisible);

        _panel.OpenHistory();
        Assert.False(_panel.UndoBarVisible);
        _app.Advance(PriorityFlow.UndoLifetime);
        _panel.CloseHistory();

        Assert.False(_panel.UndoBarVisible);
        Assert.Null(_panel.Flow.Undo);
    }
}

public sealed class PanelLifecycleTests : IDisposable
{
    private readonly AppHarness _app = new("2026-10-12T09:00:00");
    private readonly PanelState _panel;

    public PanelLifecycleTests() => _panel = _app.Panel();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void LeavingTheNotesTabSavesTheNoteAtOnce()
    {
        _panel.SelectTab(PanelTab.Notes);
        _panel.Notes.Edit("Before the switch");

        _panel.SelectTab(PanelTab.Priorities);

        Assert.Equal("Before the switch", _app.Store.NoteBody(NoteScope.Day));
    }

    [Fact]
    public void AScopeChangeSavesTheNoteOfTheOldScope()
    {
        _panel.SelectTab(PanelTab.Notes);
        _panel.Notes.Edit("Day text");

        _panel.SelectScope(PriorityList.Week);

        Assert.Equal("Day text", _app.Store.NoteBody(NoteScope.Day));
        Assert.Equal(NoteScope.Week, _panel.Notes.Scope);
    }

    [Fact]
    public void OpeningTheSettingsSavesTheNote()
    {
        _panel.SelectTab(PanelTab.Notes);
        _panel.Notes.Edit("Then the gear");

        _panel.OpenSettings();

        Assert.Equal("Then the gear", _app.Store.NoteBody(NoteScope.Day));
    }

    [Fact]
    public void FocusLossSavesTheNoteAndTheDetailNote()
    {
        var first = _app.Store.Add("First");
        _panel.Notes.Edit("Day note");
        _panel.OpenDetail(first.Id);
        _panel.Detail!.Note.Edit("Priority note");

        _panel.OnDeactivated();

        Assert.Equal("Day note", _app.Store.NoteBody(NoteScope.Day));
        Assert.Equal("Priority note", _app.Store.Find(first.Id)!.Note);
    }

    [Fact]
    public void QuitSavesTheNote()
    {
        _panel.Notes.Edit("Last words");

        _panel.OnQuit();

        Assert.Equal("Last words", _app.Store.NoteBody(NoteScope.Day));
    }

    [Fact]
    public void FocusFindsANewDayAndShowsItsNote()
    {
        using var test = new TestStore(new TestClock("2026-10-12T09:00:00"));
        using var clock = new UiClock(test.Clock);
        using var motion = new MotionPolicy(new FakeAnimationSource(), AppHarness.RowLeave);
        using var panel = new PanelState(
            test.Store, clock, motion, new StartupSettings(new FakeStartupService()), new ShortcutSettings(new FakeHotkey()));
        test.Store.SaveNote(NoteScope.Day, "Monday text");
        var days = 0;
        clock.DayChanged += (_, _) => days++;
        Assert.Equal("Monday text", panel.Notes.Text);

        test.Clock.Set("2026-10-13T08:00:00");
        panel.OnActivated();

        Assert.Equal("2026-10-13", panel.Notes.Period);
        Assert.Equal("", panel.Notes.Text);
        Assert.Equal("Monday text", test.Store.NoteBody(NoteScope.Day, "2026-10-12"));
        Assert.Equal(1, days);
    }

    [Fact]
    public void FocusReadsTheStartupStateAgain()
    {
        _app.StartupService.State = StartupStatus.OnButDisabledByUser;

        _panel.OnActivated();

        Assert.True(_panel.Startup.NeedsApproval);
    }

    [Fact]
    public void ANoteChangedFromOutsideShowsAfterTheDataChange()
    {
        _app.Execute("INSERT INTO note (scope, period, body, updated_at) VALUES ('day', '2026-10-12', 'From sqlite3', '2026-10-12T09:01:00')");

        _app.Store.CheckForExternalChanges();

        Assert.Equal("From sqlite3", _panel.Notes.Text);
    }
}
