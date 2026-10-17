using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.App;

public sealed class PriorityFlowTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PriorityFlow _flow;

    public PriorityFlowTests() => _flow = _app.Flow();

    public void Dispose() => _app.Dispose();

    private bool IsDone(Priority priority) => _app.Store.Find(priority.Id)!.IsDone;

    [Fact]
    public void TheCheckboxOpensTheConfirmationAndCancelClosesIt()
    {
        var first = _app.Store.Add("First");

        Assert.Null(_flow.ConfirmingId);
        _flow.ToggleConfirmation(first.Id);
        Assert.Equal(first.Id, _flow.ConfirmingId);
        Assert.Equal(RowPhase.Confirming, _flow.PhaseOf(first.Id));

        _flow.CancelConfirmation();
        Assert.Null(_flow.ConfirmingId);
        Assert.Equal(RowPhase.Idle, _flow.PhaseOf(first.Id));
        Assert.False(IsDone(first));
        Assert.Equal([Created], _app.Store.Types(first.Id));
    }

    [Fact]
    public void ASecondClickOnTheCheckboxCancels()
    {
        var first = _app.Store.Add("First");

        _flow.ToggleConfirmation(first.Id);
        _flow.ToggleConfirmation(first.Id);

        Assert.Null(_flow.ConfirmingId);
        Assert.Null(_flow.Undo);
    }

    [Fact]
    public void OnlyOneConfirmationIsOpenAtATime()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");

        _flow.ToggleConfirmation(first.Id);
        _flow.ToggleConfirmation(second.Id);

        Assert.Equal(second.Id, _flow.ConfirmingId);
        Assert.Equal(RowPhase.Idle, _flow.PhaseOf(first.Id));
    }

    [Fact]
    public void ConfirmingMarksDoneWritesTheEventAndShowsTheUndo()
    {
        var first = _app.Store.Add("Send the report");

        _flow.ToggleConfirmation(first.Id);
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        Assert.Null(_flow.ConfirmingId);
        Assert.True(IsDone(first));
        Assert.Empty(_app.Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([Created, Done], _app.Store.Types(first.Id));
        Assert.Equal(first.Id, _flow.Undo?.PriorityId);
        Assert.Equal("Send the report", _flow.Undo?.Title);
        Assert.False(_flow.SaveFailed);
    }

    [Fact]
    public void NothingIsMarkedDoneBeforeTheConfirmation()
    {
        var first = _app.Store.Add("First");

        _flow.ToggleConfirmation(first.Id);
        _app.Advance(TimeSpan.FromMinutes(1));

        Assert.False(IsDone(first));
        Assert.Null(_flow.Undo);
    }

    [Fact]
    public void UndoRestoresThePriorityWritesTheEventAndHighlightsIt()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        _flow.UndoDone();

        Assert.Null(_flow.Undo);
        Assert.False(IsDone(first));
        Assert.Equal([first.Id], _app.Store.OpenPriorities(PriorityList.Today).Ids());
        Assert.Equal([Created, Done, Restored], _app.Store.Types(first.Id));
        Assert.Equal(first.Id, _flow.HighlightedId);
    }

    [Fact]
    public void TheUndoBarEndsAfterFiveSeconds()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        _app.AdvanceMs(4999);
        Assert.NotNull(_flow.Undo);

        _app.AdvanceMs(1);
        Assert.Null(_flow.Undo);
        Assert.True(IsDone(first));
    }

    [Fact]
    public void ASecondDoneReplacesTheFirstUndoAndRestartsTheFiveSeconds()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        _app.AdvanceMs(3000);

        _flow.ConfirmDone(second.Id, DoneOrigin.Detail);
        Assert.Equal(second.Id, _flow.Undo?.PriorityId);
        Assert.Equal("Second", _flow.Undo?.Title);

        _app.AdvanceMs(2500);
        Assert.Equal(second.Id, _flow.Undo?.PriorityId);

        _app.AdvanceMs(2500);
        Assert.Null(_flow.Undo);
    }

    [Fact]
    public void EachUndoBarHasANewToken()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        var token = _flow.Undo!.Token;

        _flow.ConfirmDone(second.Id, DoneOrigin.Detail);

        Assert.NotEqual(token, _flow.Undo!.Token);
    }

    [Fact]
    public void UndoAfterASecondDoneRestoresOnlyTheSecond()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        _flow.ConfirmDone(second.Id, DoneOrigin.Detail);

        _flow.UndoDone();

        Assert.False(IsDone(second));
        Assert.True(IsDone(first));
    }

    [Fact]
    public void RestoringFromTheDoneListClosesItsUndoBarAndFlashesTheRow()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        _flow.Restore(first.Id);

        Assert.Null(_flow.Undo);
        Assert.False(IsDone(first));
        Assert.Equal(first.Id, _flow.HighlightedId);
    }

    [Fact]
    public void RestoringAnotherPriorityKeepsTheUndoBar()
    {
        var first = _app.Store.Add("First");
        var older = _app.Store.MarkDone(_app.Store.Add("Older").Id);
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        _flow.Restore(older.Id);

        Assert.Equal(first.Id, _flow.Undo?.PriorityId);
    }

    [Fact]
    public void DeletingThePriorityOfTheUndoBarClosesIt()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        _flow.Delete(first.Id);

        Assert.Null(_flow.Undo);
        Assert.Null(_app.Store.Find(first.Id));
    }

    [Fact]
    public void AFailedWriteKeepsTheStateAndRaisesTheFlag()
    {
        var first = _app.Store.Add("First");
        _flow.ToggleConfirmation(first.Id);
        _app.Store.Delete(first.Id);

        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        Assert.True(_flow.SaveFailed);
        Assert.Null(_flow.Undo);
        Assert.Equal(first.Id, _flow.ConfirmingId);
    }

    [Fact]
    public void ALaterWriteThatWorksClearsTheFlag()
    {
        var first = _app.Store.Add("First");
        _flow.Delete("missing");
        Assert.True(_flow.SaveFailed);

        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        Assert.False(_flow.SaveFailed);
    }

    [Fact]
    public void TheHighlightEndsAfter1400Milliseconds()
    {
        _flow.Flash("a");
        Assert.Equal("a", _flow.HighlightedId);

        _app.AdvanceMs(1399);
        Assert.Equal("a", _flow.HighlightedId);

        _app.AdvanceMs(1);
        Assert.Null(_flow.HighlightedId);
    }

    [Fact]
    public void ANewHighlightIsNotClearedByTheOldTimer()
    {
        _flow.Flash("a");
        _app.AdvanceMs(1000);
        _flow.Flash("b");

        _app.AdvanceMs(500);
        Assert.Equal("b", _flow.HighlightedId);

        _app.AdvanceMs(900);
        Assert.Null(_flow.HighlightedId);
    }

    [Fact]
    public void TheScrollTargetIsClearedWhenTheViewHandlesItAndTheHighlightStays()
    {
        _flow.Flash("a");
        Assert.Equal("a", _flow.ScrollTargetId);

        _flow.ScrollWasHandled("other");
        Assert.Equal("a", _flow.ScrollTargetId);

        _flow.ScrollWasHandled("a");
        Assert.Null(_flow.ScrollTargetId);
        Assert.Equal("a", _flow.HighlightedId);
    }

    [Fact]
    public void TheScrollTargetClearsWhenTheHighlightEnds()
    {
        _flow.Flash("a");

        _app.Advance(PriorityFlow.HighlightLifetime);

        Assert.Null(_flow.ScrollTargetId);
        Assert.Null(_flow.HighlightedId);
    }

    [Fact]
    public void ANewFlashMovesTheScrollTarget()
    {
        _flow.Flash("a");
        _flow.Flash("b");

        Assert.Equal("b", _flow.ScrollTargetId);
    }

    [Fact]
    public void AnAddFlashesTheNewRow()
    {
        var result = _flow.Add("  New  ", PriorityList.Week, PriorityLevel.High, null);

        Assert.Equal(AddResult.Added, result);
        var added = Assert.Single(_app.Store.OpenPriorities(PriorityList.Week));
        Assert.Equal("New", added.Title);
        Assert.Equal(added.Id, _flow.HighlightedId);
        Assert.Equal(added.Id, _flow.ScrollTargetId);
    }

    [Fact]
    public void AFailedAddRaisesTheFlag()
    {
        _app.Execute("DROP TABLE priority_event");

        Assert.Equal(AddResult.SaveFailed, _flow.Add("New", PriorityList.Today, PriorityLevel.Medium, null));

        Assert.True(_flow.SaveFailed);
        Assert.Null(_flow.HighlightedId);
    }

    [Fact]
    public void OpeningTheSubtasksOfARowKeepsEachRowApartAndWritesNothing()
    {
        var first = _app.Store.Add("First");

        Assert.False(_flow.IsExpanded(first.Id));
        _flow.ToggleSubtasks(first.Id);
        _flow.ToggleSubtasks("b");
        _flow.ToggleSubtasks(first.Id);

        Assert.False(_flow.IsExpanded(first.Id));
        Assert.True(_flow.IsExpanded("b"));
        Assert.Equal([Created], _app.Store.Types(first.Id));
    }
}

public sealed class PriorityLeaveTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PriorityFlow _flow;

    public PriorityLeaveTests() => _flow = _app.Flow();

    public void Dispose() => _app.Dispose();

    private bool IsDone(Priority priority) => _app.Store.Find(priority.Id)!.IsDone;

    [Fact]
    public void ARowStaysOpenForTheLeaveTimeAndThenIsMarkedDone()
    {
        var first = _app.Store.Add("First");
        _flow.ToggleConfirmation(first.Id);

        _flow.ConfirmDone(first.Id, DoneOrigin.List);

        Assert.Equal(RowPhase.Leaving, _flow.PhaseOf(first.Id));
        Assert.Equal([first.Id], _flow.LeavingIds);
        Assert.False(IsDone(first));
        Assert.Null(_flow.Undo);

        _app.AdvanceMs(319);
        Assert.False(IsDone(first));

        _app.AdvanceMs(1);
        Assert.Equal(RowPhase.Idle, _flow.PhaseOf(first.Id));
        Assert.True(IsDone(first));
        Assert.Null(_flow.ConfirmingId);
        Assert.Equal(first.Id, _flow.Undo?.PriorityId);
        Assert.False(_flow.SaveFailed);
    }

    [Fact]
    public void ASecondHechaWhileTheRowLeavesDoesNothing()
    {
        var first = _app.Store.Add("First");
        _flow.ToggleConfirmation(first.Id);

        _flow.ConfirmDone(first.Id, DoneOrigin.List);
        _flow.ConfirmDone(first.Id, DoneOrigin.List);
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        Assert.False(IsDone(first));

        _app.AdvanceMs(320);

        Assert.Equal([Created, Done], _app.Store.Types(first.Id));
    }

    [Fact]
    public void TheCheckboxAndCancelDoNothingWhileTheRowLeaves()
    {
        var first = _app.Store.Add("First");
        _flow.ToggleConfirmation(first.Id);
        _flow.ConfirmDone(first.Id, DoneOrigin.List);

        _flow.ToggleConfirmation(first.Id);
        _flow.CancelConfirmation();

        Assert.Equal(first.Id, _flow.ConfirmingId);
        Assert.Equal(RowPhase.Leaving, _flow.PhaseOf(first.Id));
    }

    [Fact]
    public void DeshacerDuringTheLeaveRestoresTheEarlierRowAndTheLeavingRowStillGoes()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        _flow.ToggleConfirmation(second.Id);
        _flow.ConfirmDone(second.Id, DoneOrigin.List);
        _flow.UndoDone();

        Assert.False(IsDone(first));
        Assert.Null(_flow.Undo);
        Assert.True(_flow.IsLeaving(second.Id));
        Assert.False(IsDone(second));

        _app.AdvanceMs(320);

        Assert.True(IsDone(second));
        Assert.False(IsDone(first));
        Assert.Equal(second.Id, _flow.Undo?.PriorityId);
        Assert.Equal("Second", _flow.Undo?.Title);
        Assert.False(_flow.IsLeaving(second.Id));
    }

    [Fact]
    public void DeshacerAfterTheLeaveRestoresTheRowThatLeft()
    {
        var first = _app.Store.Add("First");
        _flow.ToggleConfirmation(first.Id);
        _flow.ConfirmDone(first.Id, DoneOrigin.List);
        _app.AdvanceMs(320);

        _flow.UndoDone();

        Assert.False(IsDone(first));
        Assert.Null(_flow.Undo);
        Assert.Equal(first.Id, _flow.HighlightedId);
        Assert.Equal([Created, Done, Restored], _app.Store.Types(first.Id));
    }

    [Fact]
    public void RemovingARowWhileItLeavesStopsTheDoneWrite()
    {
        var first = _app.Store.Add("First");
        _flow.ToggleConfirmation(first.Id);
        _flow.ConfirmDone(first.Id, DoneOrigin.List);

        _flow.Delete(first.Id);
        _app.AdvanceMs(320);

        Assert.Null(_app.Store.Find(first.Id));
        Assert.Null(_flow.Undo);
        Assert.False(_flow.SaveFailed);
        Assert.False(_flow.IsLeaving(first.Id));
        Assert.Null(_flow.ConfirmingId);
    }

    [Fact]
    public void ARowRemovedByAnotherPathWhileItLeavesDoesNotFailTheWrite()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.List);

        _app.Store.Delete(first.Id);
        _app.AdvanceMs(320);

        Assert.Null(_flow.Undo);
        Assert.False(_flow.SaveFailed);
        Assert.False(_flow.IsLeaving(first.Id));
    }

    [Fact]
    public void TheConfirmationOfAnotherRowSurvivesTheEndOfTheLeave()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _flow.ToggleConfirmation(first.Id);
        _flow.ConfirmDone(first.Id, DoneOrigin.List);
        _flow.ToggleConfirmation(second.Id);

        _app.AdvanceMs(320);

        Assert.Equal(second.Id, _flow.ConfirmingId);
        Assert.True(IsDone(first));
    }

    [Fact]
    public void WithReducedMotionTheRowLeavesAtOnce()
    {
        var first = _app.Store.Add("First");
        _app.Animations.Set(enabled: false);
        _flow.ToggleConfirmation(first.Id);

        _flow.ConfirmDone(first.Id, DoneOrigin.List);

        Assert.False(_flow.IsLeaving(first.Id));
        Assert.True(IsDone(first));
        Assert.Equal(first.Id, _flow.Undo?.PriorityId);
    }

    [Fact]
    public void TheUndoBarGoesAwayAfterItsLifetimeWithEitherSetting()
    {
        foreach (var enabled in new[] { true, false })
        {
            _app.Animations.Set(enabled);
            var priority = _app.Store.Add($"Animations {enabled}");
            _flow.ConfirmDone(priority.Id, DoneOrigin.List);
            _app.Advance(_app.Motion.LeaveDelay);
            Assert.NotNull(_flow.Undo);

            _app.Advance(PriorityFlow.UndoLifetime);

            Assert.Null(_flow.Undo);
        }
    }
}

public sealed class UndoLineTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly PriorityFlow _flow;

    public UndoLineTests() => _flow = _app.Flow();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void TheLineIsFullWhenTheTimerStarts()
    {
        var first = _app.Store.Add("First");

        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);

        var undo = _flow.Undo!;
        Assert.Equal(_app.Clock.Instant, undo.StartedAt);
        Assert.Equal(TimeSpan.FromSeconds(5), undo.Lifetime);
        Assert.Equal(1, undo.RemainingFraction(_app.Clock.Instant));
    }

    [Fact]
    public void TheLineGetsShorterWhileTheTimerRuns()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        var undo = _flow.Undo!;

        _app.AdvanceMs(2500);
        Assert.Equal(0.5, undo.RemainingFraction(_app.Clock.Instant), 4);

        _app.AdvanceMs(1250);
        Assert.Equal(0.25, undo.RemainingFraction(_app.Clock.Instant), 4);

        Assert.Equal(0, undo.RemainingFraction(_app.Clock.Instant.AddSeconds(10)));
    }

    [Fact]
    public void ASecondDoneStartsANewFullLine()
    {
        var first = _app.Store.Add("First");
        var second = _app.Store.Add("Second");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        _app.AdvanceMs(3000);

        _flow.ConfirmDone(second.Id, DoneOrigin.Detail);

        Assert.Equal("Second", _flow.Undo!.Title);
        Assert.Equal(1, _flow.Undo.RemainingFraction(_app.Clock.Instant));
    }

    [Fact]
    public void TheLineDoesNotMoveWithReducedMotion()
    {
        var first = _app.Store.Add("First");
        _flow.ConfirmDone(first.Id, DoneOrigin.Detail);
        var undo = _flow.Undo!;

        _app.AdvanceMs(3000);

        Assert.Equal(1, undo.LineFraction(_app.Clock.Instant, reduceMotion: true));
        Assert.True(undo.LineFraction(_app.Clock.Instant, reduceMotion: false) < 1);
    }
}
