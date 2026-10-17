using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.App;

public sealed class CaptureModelTests : IDisposable
{
    private readonly AppHarness _app = new();
    private readonly CaptureModel _capture;
    private readonly List<CaptureCloseReason> _closes = [];
    private int _opens;

    public CaptureModelTests()
    {
        _capture = _app.Own(new CaptureModel(_app.Store));
        _capture.Opened += (_, _) => _opens++;
        _capture.Closed += (_, reason) => _closes.Add(reason);
    }

    public void Dispose() => _app.Dispose();

    private void OpenWith(string title)
    {
        _capture.Open();
        _capture.Title = title;
    }

    [Fact]
    public void StartsClosedAndEmptyWithNoNotice()
    {
        Assert.False(_capture.IsOpen);
        Assert.Equal("", _capture.Title);
        Assert.Equal(CaptureNotice.None, _capture.Notice);
    }

    [Fact]
    public void OpeningTwiceOpensOnce()
    {
        _capture.Open();
        _capture.Open();

        Assert.True(_capture.IsOpen);
        Assert.Equal(1, _opens);
    }

    [Fact]
    public void ClosingAClosedWindowDoesNothing()
    {
        _capture.Cancel();
        _capture.Open();
        _capture.Cancel();
        _capture.Dismiss();

        Assert.Equal([CaptureCloseReason.Escape], _closes);
    }

    [Fact]
    public void TheShortcutOpensThenCloses()
    {
        _capture.Attach(_app.Hotkey);

        _app.Hotkey.Press();
        Assert.True(_capture.IsOpen);

        _capture.Title = "No guardar";
        _app.Hotkey.Press();
        Assert.False(_capture.IsOpen);
        Assert.Equal([CaptureCloseReason.Shortcut], _closes);
        Assert.Equal(0, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void AttachingTwiceListensOnce()
    {
        _capture.Attach(_app.Hotkey);
        _capture.Attach(_app.Hotkey);

        Assert.Equal(1, _app.Hotkey.Subscribers);

        _capture.Dispose();
        Assert.Equal(0, _app.Hotkey.Subscribers);
    }

    [Fact]
    public void EscapeClosesWithNoAddAndGivesTheFocusBack()
    {
        OpenWith("No guardar");

        _capture.Cancel();

        Assert.False(_capture.IsOpen);
        Assert.Equal(0, _app.Store.OpenCount(PriorityList.Today));
        Assert.True(Assert.Single(_closes).RestoresFocus());
    }

    [Fact]
    public void AClickElsewhereClosesWithNoAddAndDoesNotGiveTheFocusBack()
    {
        OpenWith("No guardar");

        _capture.Dismiss();

        Assert.False(_capture.IsOpen);
        Assert.Equal(0, _app.Store.OpenCount(PriorityList.Today));
        Assert.False(Assert.Single(_closes).RestoresFocus());
    }

    [Fact]
    public void AnEmptyOrBlankTitleAddsNothingAndKeepsTheWindowOpen()
    {
        _capture.Open();
        _capture.Submit();
        _capture.Title = "  \n ";
        _capture.Submit();

        Assert.True(_capture.IsOpen);
        Assert.Equal("  \n ", _capture.Title);
        Assert.Equal(CaptureNotice.None, _capture.Notice);
        Assert.Equal(0, _app.Store.OpenCount(PriorityList.Today));
        Assert.Empty(_closes);
    }

    [Fact]
    public void EnterAddsATrimmedTitleToHoyWithMediaAndNoDueThenCloses()
    {
        OpenWith("  Pagar la luz  ");

        _capture.Submit();

        var added = Assert.Single(_app.Store.OpenPriorities(PriorityList.Today));
        Assert.Equal("Pagar la luz", added.Title);
        Assert.Equal(PriorityLevel.Medium, added.Level);
        Assert.Null(added.DueAt);
        Assert.Equal("", added.Note);
        Assert.Equal([PriorityEventType.Created], _app.Store.Types(added.Id));
        Assert.Empty(_app.Store.Alerts());
        Assert.False(_capture.IsOpen);
        Assert.Equal([CaptureCloseReason.Added], _closes);
        Assert.True(CaptureCloseReason.Added.RestoresFocus());
    }

    [Fact]
    public void AtTheLimitTheWindowStaysOpenWithTheTextAndTheNotice()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        OpenWith("Una más");

        _capture.Submit();

        Assert.True(_capture.IsOpen);
        Assert.Equal("Una más", _capture.Title);
        Assert.Equal(CaptureNotice.TodayLimit, _capture.Notice);
        Assert.Equal(5, _app.Rows<long>("SELECT COUNT(*) FROM priority").Single());
        Assert.Empty(_closes);
    }

    [Fact]
    public void WithTheLimitOnAndFourOpenTheAddWorks()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(4);
        OpenWith("La quinta");

        _capture.Submit();

        Assert.False(_capture.IsOpen);
        Assert.Equal(5, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void WithTheLimitOffTheAddWorksWithManyOpen()
    {
        _app.Fill(7);
        OpenWith("La octava");

        _capture.Submit();

        Assert.Equal(8, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void TheNoticeGoesWhenALaterAddWorks()
    {
        _app.TurnOnTodayLimit();
        var today = _app.Fill(5);
        OpenWith("Una más");
        _capture.Submit();

        _app.Store.MarkDone(today[0].Id);
        _capture.Submit();

        Assert.Equal(CaptureNotice.None, _capture.Notice);
        Assert.Equal("", _capture.Title);
        Assert.False(_capture.IsOpen);
    }

    [Fact]
    public void AFailedWriteKeepsTheTextAndShowsTheSaveNotice()
    {
        _app.Execute("DROP TABLE priority_event");
        OpenWith("Pagar la luz");

        _capture.Submit();

        Assert.True(_capture.IsOpen);
        Assert.Equal(CaptureNotice.SaveFailed, _capture.Notice);
        Assert.Equal("Pagar la luz", _capture.Title);
        Assert.Equal(0, _app.Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void EachOpenStartsWithAnEmptyFieldAndNoNotice()
    {
        _app.TurnOnTodayLimit();
        _app.Fill(5);
        OpenWith("Texto viejo");
        _capture.Submit();
        _capture.Cancel();

        _capture.Open();

        Assert.Equal("", _capture.Title);
        Assert.Equal(CaptureNotice.None, _capture.Notice);
    }
}
