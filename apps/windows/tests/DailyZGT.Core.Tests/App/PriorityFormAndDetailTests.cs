using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.App;

public sealed class NewPriorityFormTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PriorityFlow _flow;

    public NewPriorityFormTests() => _flow = _app.Flow();

    public void Dispose() => _app.Dispose();

    private NewPriorityForm Form(PriorityList list = PriorityList.Today) => new(_app.Store, _flow, _app.Clock, list);

    private static void AssertReset(NewPriorityForm form)
    {
        Assert.False(form.IsOpen);
        Assert.Equal("", form.Title);
        Assert.Equal(PriorityLevel.Medium, form.Level);
        Assert.Null(form.DueAt);
        Assert.False(form.IsBlockedByLimit);
    }

    [Fact]
    public void StartsClosedWithMediumLevelAndNoDue()
    {
        var form = Form();

        AssertReset(form);
        Assert.False(form.ShowsDueNote);
    }

    [Fact]
    public void TheTitleIsTrimmed()
    {
        var form = Form();
        form.Title = "  \n Send the report \t ";

        form.Submit();

        Assert.Equal(["Send the report"], _app.Store.OpenPriorities(PriorityList.Today).Titles());
    }

    [Fact]
    public void AnEmptyOrBlankTitleDoesNotAddAndKeepsTheForm()
    {
        var form = Form();
        form.Open();
        form.Submit();
        form.Title = "   \n ";

        form.Submit();

        Assert.Empty(_app.Store.OpenPriorities(PriorityList.Today));
        Assert.True(form.IsOpen);
        Assert.Equal("   \n ", form.Title);
        Assert.False(_flow.SaveFailed);
    }

    [Fact]
    public void TheChosenLevelAndDueAreUsed()
    {
        var form = Form();
        form.Title = "Urgent";
        form.Level = PriorityLevel.High;
        form.DueAt = Time.At("2026-10-12T16:00:00");
        Assert.True(form.ShowsDueNote);

        form.Submit();

        var added = Assert.Single(_app.Store.OpenPriorities(PriorityList.Today));
        Assert.Equal(PriorityLevel.High, added.Level);
        Assert.Equal(Time.At("2026-10-12T16:00:00"), added.DueAt);
    }

    [Fact]
    public void TheNewPriorityGoesToTheListOfTheForm()
    {
        var form = Form(PriorityList.Week);
        form.Title = "For the week";
        form.Submit();
        form.List = PriorityList.Today;
        form.Title = "For today";
        form.Submit();

        Assert.Equal(["For the week"], _app.Store.OpenPriorities(PriorityList.Week).Titles());
        Assert.Equal(["For today"], _app.Store.OpenPriorities(PriorityList.Today).Titles());
    }

    [Fact]
    public void ASuccessfulAddClosesResetsAndFlashesTheNewRow()
    {
        var form = Form();
        form.Open();
        form.Title = "Done";
        form.Level = PriorityLevel.Low;
        form.DueAt = Time.At("2026-10-12T16:00:00");

        form.Submit();

        AssertReset(form);
        var added = Assert.Single(_app.Store.OpenPriorities(PriorityList.Today));
        Assert.Equal(added.Id, _flow.HighlightedId);
        Assert.Equal(added.Id, _flow.ScrollTargetId);
    }

    [Fact]
    public void CancelClosesAndClearsTheDraft()
    {
        var form = Form();
        form.Open();
        form.Title = "Draft";
        form.Level = PriorityLevel.High;
        form.PickDefaultDue();

        form.Cancel();

        AssertReset(form);
    }

    [Fact]
    public void EscapeClosesAndKeepsTheDraft()
    {
        var form = Form();
        form.Open();
        form.Title = "Draft";

        form.Close();
        Assert.False(form.IsOpen);
        Assert.Equal("Draft", form.Title);

        form.Open();
        Assert.Equal("Draft", form.Title);
    }

    [Fact]
    public void TheDefaultDueIsTheNextWholeHour()
    {
        Assert.Equal(Time.At("2026-10-12T11:00:00"), NewPriorityForm.NextWholeHour(Time.At("2026-10-12T10:24:00")));
        Assert.Equal(Time.At("2026-10-12T11:00:00"), NewPriorityForm.NextWholeHour(Time.At("2026-10-12T10:00:00")));
        Assert.Equal(Time.At("2026-10-13T00:00:00"), NewPriorityForm.NextWholeHour(Time.At("2026-10-12T23:30:00")));

        var form = Form();
        form.PickDefaultDue();
        Assert.Equal(Time.At("2026-10-12T11:00:00"), form.DueAt);

        form.ClearDue();
        Assert.Null(form.DueAt);
    }

    [Fact]
    public void AFailedAddKeepsTheDraftAndRaisesTheListFlag()
    {
        var form = Form();
        form.Open();
        form.Title = "Lost?";
        _app.Execute("DROP TABLE priority_event");

        form.Submit();

        Assert.True(form.IsOpen);
        Assert.Equal("Lost?", form.Title);
        Assert.True(_flow.SaveFailed);
    }

    [Fact]
    public void InHoyAtTheLimitTheFormDoesNotAddAndKeepsTheText()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        var form = Form();
        form.Open();
        form.Title = "Una más";
        form.Level = PriorityLevel.High;
        form.DueAt = Time.At("2026-10-12T16:00:00");

        form.Submit();

        Assert.True(form.ShowsLimitNotice);
        Assert.True(form.IsOpen);
        Assert.Equal("Una más", form.Title);
        Assert.Equal(PriorityLevel.High, form.Level);
        Assert.Equal(Time.At("2026-10-12T16:00:00"), form.DueAt);
        Assert.Equal(5, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void InHoyWithFourOpenTheFormAdds()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(4);
        var form = Form();
        form.Title = "La quinta";

        form.Submit();

        Assert.False(form.ShowsLimitNotice);
        Assert.Equal(5, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void InSemanaTheFormIsNeverBlocked()
    {
        _app.Fill(6);
        _app.TurnOnTodayLimit();
        var form = Form(PriorityList.Week);
        form.Title = "Para la semana";

        form.Submit();

        Assert.False(form.ShowsLimitNotice);
        Assert.Single(_app.Store.OpenPriorities(PriorityList.Week));
    }

    [Fact]
    public void TheNoticeGoesWhenHoyHasRoomAndTheFormThenAdds()
    {
        _app.TurnOnTodayLimit();
        var today = _app.Fill(5);
        var form = Form();
        form.Title = "Una más";
        form.Submit();
        Assert.True(form.ShowsLimitNotice);

        _app.Store.MarkDone(today[0].Id);
        Assert.False(form.ShowsLimitNotice);
        form.Submit();

        AssertReset(form);
        Assert.Contains("Una más", _app.Store.OpenPriorities(PriorityList.Today).Titles());
    }

    [Fact]
    public void TheNoticeShowsOnlyInHoy()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        var form = Form();
        form.Title = "Una más";
        form.Submit();

        form.List = PriorityList.Week;
        Assert.False(form.ShowsLimitNotice);

        form.List = PriorityList.Today;
        Assert.True(form.ShowsLimitNotice);
    }

    [Fact]
    public void ABlankTitleAtTheLimitShowsNoNotice()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        var form = Form();
        form.Title = "   ";

        form.Submit();

        Assert.False(form.ShowsLimitNotice);
    }

    [Fact]
    public void CancelClearsTheLimitMark()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        var form = Form();
        form.Title = "Una más";
        form.Submit();

        form.Cancel();

        AssertReset(form);
        Assert.False(form.ShowsLimitNotice);
    }

    [Fact]
    public void WithTheSettingOffTheFormAddsWithFiveOpen()
    {
        _app.Fill(5);
        var form = Form();
        form.Title = "La sexta";

        form.Submit();

        Assert.Equal(6, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void UndoAndRegresarGiveBackAPriorityAtTheLimit()
    {
        _app.TurnOnTodayLimit();
        var today = _app.Fill(5);
        _flow.ConfirmDone(today[0].Id, DoneOrigin.Detail);
        _app.Store.MarkDone(today[1].Id);
        _app.Store.Add("Sexta");
        _app.Store.Add("Séptima");

        _flow.UndoDone();
        _flow.Restore(today[1].Id);

        Assert.Equal(7, _app.Store.OpenCount(PriorityList.Today));
        Assert.False(_flow.SaveFailed);
    }
}

public sealed class PriorityDetailModelTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly List<PriorityList> _moves = [];

    public void Dispose() => _app.Dispose();

    private PriorityDetailModel Detail(Priority priority) =>
        _app.Own(new PriorityDetailModel(_app.Store, _app.Clock, priority, _moves.Add));

    private (Priority, PriorityDetailModel) Setup()
    {
        var priority = _app.Store.Add("Old title");
        return (priority, Detail(priority));
    }

    [Fact]
    public void ANewTitleWritesTheRowAndAnEditedEvent()
    {
        var (priority, detail) = Setup();
        _app.Advance(TimeSpan.FromMinutes(5));

        detail.BeginTitleEdit();
        detail.TitleDraft = "  New title ";
        detail.CommitTitle();

        Assert.Equal("New title", detail.TitleDraft);
        Assert.Equal(TitleEditState.Idle, detail.TitleState);
        Assert.Equal("New title", _app.Store.Find(priority.Id)!.Title);
        Assert.Equal([Created, Edited], _app.Store.Types(priority.Id));
        Assert.Equal(Time.At("2026-10-12T10:29:00"), _app.Store.Find(priority.Id)!.UpdatedAt);
    }

    [Fact]
    public void AnEmptyOrSameTitleGoesBackToTheSavedTitleAndWritesNothing()
    {
        var (priority, detail) = Setup();

        foreach (var draft in new[] { "   ", "", "Old title", "Old title  " })
        {
            detail.BeginTitleEdit();
            detail.TitleDraft = draft;
            detail.CommitTitle();
            Assert.Equal("Old title", detail.TitleDraft);
        }

        Assert.Equal([Created], _app.Store.Types(priority.Id));
    }

    [Fact]
    public void EscapeDiscardsTheDraft()
    {
        var (priority, detail) = Setup();
        detail.BeginTitleEdit();
        detail.TitleDraft = "Never saved";

        detail.DiscardTitle();

        Assert.Equal("Old title", detail.TitleDraft);
        Assert.Equal(TitleEditState.Idle, detail.TitleState);
        Assert.Equal([Created], _app.Store.Types(priority.Id));
    }

    [Fact]
    public void ATitleChangedFromOutsideReplacesTheFieldOnlyWhenTheFieldIsNotBeingEdited()
    {
        var (priority, detail) = Setup();
        detail.BeginTitleEdit();
        detail.TitleDraft = "Typing";
        _app.Store.EditTitle(priority.Id, "From outside");

        detail.Refresh();
        Assert.Equal("Typing", detail.TitleDraft);

        detail.DiscardTitle();
        Assert.Equal("From outside", detail.TitleDraft);
    }

    [Fact]
    public void ANewLevelWritesTheRowAndAnEditedEventAndTheSameLevelWritesNone()
    {
        var (priority, detail) = Setup();

        detail.SetLevel(PriorityLevel.Medium);
        Assert.Equal([Created], _app.Store.Types(priority.Id));

        detail.SetLevel(PriorityLevel.High);
        Assert.Equal(PriorityLevel.High, detail.Priority.Level);
        Assert.Equal(["high"], _app.Rows<string>("SELECT level FROM priority"));
        Assert.Equal([Created, Edited], _app.Store.Types(priority.Id));
    }

    [Fact]
    public void ADueCanBeSetChangedAndCleared()
    {
        var (priority, detail) = Setup();

        detail.PickDefaultDue();
        Assert.Equal(Time.At("2026-10-12T11:00:00"), detail.Priority.DueAt);

        detail.SetDue(Time.At("2026-10-13T09:30:00"));
        Assert.Equal(Time.At("2026-10-13T09:30:00"), _app.Store.Find(priority.Id)!.DueAt);

        detail.SetDue(null);
        Assert.Null(_app.Store.Find(priority.Id)!.DueAt);
        Assert.Equal([Created, Edited, Edited, Edited], _app.Store.Types(priority.Id));
    }

    [Fact]
    public void MovingToTheOtherListWritesAMovedEventAndSelectsTheList()
    {
        var (priority, detail) = Setup();

        detail.SetList(PriorityList.Week);

        Assert.Equal(PriorityList.Week, detail.Priority.List);
        Assert.Equal([Created, Moved], _app.Store.Types(priority.Id));
        Assert.Equal([PriorityList.Week], _moves);
    }

    [Fact]
    public void RepeatCanBeTurnedOnAndOff()
    {
        var (priority, detail) = Setup();

        detail.SetRepeat(RepeatRule.Daily);
        Assert.Equal(RepeatRule.Daily, detail.Priority.RepeatRule);

        detail.SetRepeat(RepeatRule.None);
        Assert.Equal(RepeatRule.None, _app.Store.Find(priority.Id)!.RepeatRule);
    }

    [Fact]
    public void AWriteOnAMissingPriorityRaisesTheFlagAndALaterWriteClearsIt()
    {
        var (priority, detail) = Setup();
        var other = _app.Store.Add("Other");
        _app.Store.Delete(priority.Id);

        detail.SetLevel(PriorityLevel.High);
        Assert.True(detail.SaveFailed);

        var second = Detail(other);
        second.SetLevel(PriorityLevel.Low);
        Assert.False(second.SaveFailed);
    }

    [Fact]
    public void TheMoveToHoyIsBlockedAtTheLimitAndTheNoticeShowsAfterTheAttempt()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        var weekly = _app.Store.Add("De la semana", PriorityList.Week);
        var detail = Detail(weekly);
        Assert.False(detail.ShowsLimitNotice);

        detail.SetList(PriorityList.Today);

        Assert.True(detail.ShowsLimitNotice);
        Assert.Equal(PriorityList.Week, _app.Store.Find(weekly.Id)!.List);
        Assert.Equal([Created], _app.Store.Types(weekly.Id));
        Assert.Empty(_moves);
        Assert.False(detail.SaveFailed);
    }

    [Fact]
    public void TheNoticeGoesWhenHoyHasRoom()
    {
        _app.TurnOnTodayLimit();
        var today = _app.Fill(5);
        var detail = Detail(_app.Store.Add("De la semana", PriorityList.Week));
        detail.SetList(PriorityList.Today);

        _app.Store.MarkDone(today[0].Id);
        detail.Refresh();

        Assert.False(detail.ShowsLimitNotice);
    }

    [Fact]
    public void TheMoveToHoyWorksWithFourOpenAndClearsTheNotice()
    {
        _app.TurnOnTodayLimit();
        var today = _app.Fill(5);
        var detail = Detail(_app.Store.Add("De la semana", PriorityList.Week));
        detail.SetList(PriorityList.Today);
        _app.Store.MarkDone(today[0].Id);

        detail.SetList(PriorityList.Today);

        Assert.Equal(PriorityList.Today, detail.Priority.List);
        Assert.False(detail.ShowsLimitNotice);
        Assert.Equal([PriorityList.Today], _moves);
    }

    [Fact]
    public void TheMoveToSemanaIsNeverBlocked()
    {
        var today = _app.Fill(6);
        _app.TurnOnTodayLimit();

        Detail(today[0]).SetList(PriorityList.Week);

        Assert.Equal(PriorityList.Week, _app.Store.Find(today[0].Id)!.List);
    }

    [Fact]
    public void ClosingTheDetailSavesItsNote()
    {
        var (priority, detail) = Setup();
        detail.Note.Edit("Before closing");

        detail.Dispose();
        _app.AdvanceMs(400);

        Assert.Equal("Before closing", _app.Store.Find(priority.Id)!.Note);
        Assert.Equal(1, _app.Store.Events(priority.Id).Count(e => e.Type == Edited));
    }
}

public sealed class SubtaskEditorTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly Priority _parent;
    private readonly SubtaskEditor _editor;

    public SubtaskEditorTests()
    {
        _parent = _app.Store.Add("Parent");
        _editor = new SubtaskEditor(_app.Store, _parent.Id);
    }

    public void Dispose() => _app.Dispose();

    private List<string> Titles() => _app.Store.Subtasks(_parent.Id).Select(s => s.Title).ToList();

    [Fact]
    public void EnterAddsATrimmedSubtaskAtTheEndAndEmptiesTheField()
    {
        _editor.Draft = "  Escribir los criterios \n";
        _editor.Add();
        _editor.Draft = "Pedir  review";
        _editor.Add();

        Assert.Equal(["Escribir los criterios", "Pedir  review"], Titles());
        Assert.Equal("", _editor.Draft);
        Assert.False(_editor.SaveFailed);
    }

    [Fact]
    public void ABlankTextAddsNothingAndKeepsTheField()
    {
        foreach (var draft in new[] { "", "   ", "\n\t " })
        {
            _editor.Draft = draft;
            _editor.Add();
            Assert.Equal(draft, _editor.Draft);
        }

        Assert.Empty(Titles());
        Assert.Equal([Created], _app.Store.Types(_parent.Id));
    }

    [Fact]
    public void TheCheckboxTogglesAtOnceWithNoConfirmation()
    {
        _editor.Draft = "Step";
        _editor.Add();
        var step = Assert.Single(_app.Store.Subtasks(_parent.Id));

        _editor.Toggle(step.Id);
        Assert.True(Assert.Single(_app.Store.Subtasks(_parent.Id)).IsDone);
        Assert.False(_app.Store.Find(_parent.Id)!.IsDone);

        _editor.Toggle(step.Id);
        Assert.False(Assert.Single(_app.Store.Subtasks(_parent.Id)).IsDone);
        Assert.Equal([Created, Edited, SubtaskDone, Edited], _app.Store.Types(_parent.Id));
    }

    [Fact]
    public void AFailedAddOrToggleRaisesTheFlagAndALaterWriteClearsIt()
    {
        _editor.Toggle("missing");
        Assert.True(_editor.SaveFailed);

        _editor.Draft = "Step";
        _editor.Add();
        Assert.False(_editor.SaveFailed);

        _app.Store.Delete(_parent.Id);
        _editor.Draft = "Orphan";
        _editor.Add();
        Assert.True(_editor.SaveFailed);
        Assert.Equal("Orphan", _editor.Draft);
    }
}

public sealed class TitleRulesTests
{
    [Fact]
    public void AClickAtTheSamePointWithNoSelectionOpens() =>
        Assert.True(TitleClickRule.ShouldOpen((40, 20), (40, 20), selectionLength: 0));

    [Fact]
    public void ATinyMovementStillOpens() =>
        Assert.True(TitleClickRule.ShouldOpen((40, 20), (42, 21), selectionLength: 0));

    [Fact]
    public void ASelectionBlocksTheOpenEvenAtTheSamePoint()
    {
        Assert.False(TitleClickRule.ShouldOpen((40, 20), (90, 20), selectionLength: 6));
        Assert.False(TitleClickRule.ShouldOpen((40, 20), (40, 20), selectionLength: 1));
    }

    [Fact]
    public void ADragWithNoSelectionDoesNotOpen()
    {
        Assert.False(TitleClickRule.ShouldOpen((40, 20), (90, 20), selectionLength: 0));
        Assert.False(TitleClickRule.ShouldOpen((40, 20), (40, 30), selectionLength: 0));
    }

    [Fact]
    public void TheThreePointToleranceIsInclusive()
    {
        Assert.True(TitleClickRule.ShouldOpen((0, 0), (3, 3), selectionLength: 0));
        Assert.False(TitleClickRule.ShouldOpen((0, 0), (3.5, 0), selectionLength: 0));
    }

    [Fact]
    public void AChangedTitleIsSavedTrimmed() =>
        Assert.Equal("New title", TitleEdit.TitleToSave("  New title \n", "Old title"));

    [Fact]
    public void AnEmptyBlankOrSameTitleDoesNotSave()
    {
        Assert.Null(TitleEdit.TitleToSave("", "Old title"));
        Assert.Null(TitleEdit.TitleToSave(" \t ", "Old title"));
        Assert.Null(TitleEdit.TitleToSave("Old title", "Old title"));
        Assert.Null(TitleEdit.TitleToSave("Old title  ", "Old title"));
    }
}
