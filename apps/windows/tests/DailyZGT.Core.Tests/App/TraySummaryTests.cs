using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.App;

public sealed class TraySummaryTests : IDisposable
{
    private readonly AppHarness _app = new();

    public void Dispose() => _app.Dispose();

    private TraySummary Summary() => _app.Own(new TraySummary(_app.Store));

    [Fact]
    public void ADataErrorHasNoCountAndNoTitle()
    {
        var summary = TraySummary.DataError();

        Assert.Null(summary.Count);
        Assert.Null(summary.Title);
    }

    [Fact]
    public void AnEmptyListCountsZeroAndHasNoTitle()
    {
        var summary = Summary();

        Assert.Equal(0, summary.Count);
        Assert.Null(summary.Title);
    }

    [Fact]
    public void TheTitleIsTheFirstOpenPriorityOfHoyInListOrder()
    {
        _app.Store.Add("Low", level: PriorityLevel.Low);
        _app.Store.Add("Medium late", due: "2026-10-12T18:00:00");
        _app.Store.Add("Medium soon", due: "2026-10-12T12:00:00");
        _app.Store.Add("High", level: PriorityLevel.High);
        _app.Store.Add("Week high", PriorityList.Week, PriorityLevel.High);

        var summary = Summary();

        Assert.Equal("High", summary.Title);
        Assert.Equal(4, summary.Count);
    }

    [Fact]
    public void ALongTitleIsCut()
    {
        _app.Store.Add("Terminar el brief de Tailwind v4 para el equipo");

        Assert.Equal("Terminar el brief de Ta…", Summary().Title);
    }

    [Fact]
    public void TheCountAndTheTitleFollowEveryChange()
    {
        var summary = Summary();
        var raised = new List<string?>();
        summary.PropertyChanged += (_, e) => raised.Add(e.PropertyName);

        var first = _app.Store.Add("First");
        Assert.Equal("First", summary.Title);
        Assert.Equal(1, summary.Count);

        var second = _app.Store.Add("Second", level: PriorityLevel.High);
        Assert.Equal("Second", summary.Title);

        _app.Store.MarkDone(second.Id);
        Assert.Equal("First", summary.Title);

        _app.Store.Restore(second.Id);
        _app.Store.EditTitle(second.Id, "Second edited");
        Assert.Equal("Second edited", summary.Title);

        _app.Store.MoveToList(second.Id, PriorityList.Week);
        Assert.Equal("First", summary.Title);

        _app.Store.Delete(first.Id);
        Assert.Null(summary.Title);
        Assert.Equal(0, summary.Count);
        Assert.Contains(nameof(TraySummary.Title), raised);
        Assert.Contains(nameof(TraySummary.Count), raised);
    }

    [Fact]
    public void AWriteFromAnotherProgramShows()
    {
        var summary = Summary();
        using (var other = AppStore.OpenFile(_app.FilePath, _app.FakeTime))
        {
            other.Add("From outside");
        }

        _app.Store.CheckForExternalChanges();

        Assert.Equal("From outside", summary.Title);
    }

    [Fact]
    public void TheSettingHidesTheTitleAndKeepsTheCount()
    {
        _app.Store.Add("Pagar la luz");
        var summary = Summary();

        _app.Store.SetValue(AppStateKeys.TrayTitle, false);
        Assert.Null(summary.Title);
        Assert.Equal(1, summary.Count);

        _app.Store.SetValue(AppStateKeys.TrayTitle, true);
        Assert.Equal("Pagar la luz", summary.Title);
    }
}
