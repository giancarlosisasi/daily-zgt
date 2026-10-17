using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.App;

public sealed class NotesModelTests : IDisposable
{
    private readonly AppHarness _app = new("2026-10-12T09:00:00");

    public void Dispose() => _app.Dispose();

    private NotesModel Model(NoteScope scope = NoteScope.Day) => _app.Own(new NotesModel(_app.Store, _app.Clock, scope));

    private List<string> Rows() =>
        _app.Rows<string>("SELECT scope || '|' || period || '|' || body FROM note ORDER BY scope, period");

    [Fact]
    public void TheModelStartsWithThePeriodOfTheClock()
    {
        Assert.Equal("2026-10-12", Model().Period);
        Assert.Equal("2026-W42", Model(NoteScope.Week).Period);
    }

    [Fact]
    public void TheModelStartsWithTheSavedBody()
    {
        _app.Store.SaveNote(NoteScope.Day, "Saved");

        Assert.Equal("Saved", Model().Text);
    }

    [Fact]
    public void TypingThenWaitingSavesOnce()
    {
        var model = Model();

        model.Text = "Hola";
        Assert.Empty(Rows());
        Assert.True(model.HasUnsavedEdit);

        _app.AdvanceMs(399);
        Assert.Empty(Rows());

        _app.AdvanceMs(1);
        Assert.Equal(["day|2026-10-12|Hola"], Rows());
        Assert.False(model.HasUnsavedEdit);
        Assert.False(model.SaveFailed);
    }

    [Fact]
    public void TwoFastEditsSaveOnce()
    {
        var model = Model();

        model.Edit("H");
        _app.AdvanceMs(300);
        model.Edit("Ho");
        _app.AdvanceMs(300);
        Assert.Empty(Rows());
        Assert.True(model.HasUnsavedEdit);

        _app.AdvanceMs(100);
        Assert.Equal(["day|2026-10-12|Ho"], Rows());
    }

    [Fact]
    public void ATimerAfterAFlushWritesNothingMore()
    {
        var model = Model();
        model.Edit("First");
        model.Flush();
        _app.Advance(TimeSpan.FromMinutes(5));
        model.Edit("Second");
        model.Flush();

        _app.Advance(TimeSpan.FromSeconds(1));

        Assert.Equal(["day|2026-10-12|Second"], Rows());
        Assert.Equal(["2026-10-12T09:05:00"], _app.Rows<string>("SELECT updated_at FROM note"));
    }

    [Fact]
    public void AFlushSavesAtOnce()
    {
        var model = Model();

        model.Edit("Closing the panel");
        model.Flush();

        Assert.Equal("Closing the panel", _app.Store.NoteBody(NoteScope.Day));
        Assert.False(model.HasUnsavedEdit);
    }

    [Fact]
    public void AFlushWithNoEditWritesNothing()
    {
        Model().Flush();

        Assert.Empty(Rows());
    }

    [Fact]
    public void AScopeChangeSavesTheOldScopeFirst()
    {
        var model = Model();
        _app.Store.SaveNote(NoteScope.Week, "Week text");

        model.Edit("Day text");
        model.SelectScope(NoteScope.Week);

        Assert.Equal("Day text", _app.Store.NoteBody(NoteScope.Day));
        Assert.Equal(NoteScope.Week, model.Scope);
        Assert.Equal("2026-W42", model.Period);
        Assert.Equal("Week text", model.Text);
        Assert.False(model.HasUnsavedEdit);

        _app.AdvanceMs(400);
        Assert.Equal("Week text", _app.Store.NoteBody(NoteScope.Week));
    }

    [Fact]
    public void TheDayNoteAndTheWeekNoteAreSeparateRows()
    {
        var model = Model();

        model.Edit("Day");
        model.SelectScope(NoteScope.Week);
        model.Edit("Week");
        model.Flush();

        Assert.Equal(["day|2026-10-12|Day", "week|2026-W42|Week"], Rows());
        model.SelectScope(NoteScope.Day);
        Assert.Equal("Day", model.Text);
    }

    [Fact]
    public void ANewDayReadsAnotherRowAndTheOldTextIsSavedFirst()
    {
        _app.Store.SaveNote(NoteScope.Day, "Tomorrow plan", "2026-10-13");
        var model = Model();
        model.Edit("Monday text");

        _app.Set("2026-10-13T09:00:00");
        model.Sync();

        Assert.Equal("2026-10-13", model.Period);
        Assert.Equal("Tomorrow plan", model.Text);
        Assert.False(model.HasUnsavedEdit);
        Assert.Equal("Monday text", _app.Store.NoteBody(NoteScope.Day, "2026-10-12"));
        Assert.Equal("Tomorrow plan", _app.Store.NoteBody(NoteScope.Day, "2026-10-13"));
    }

    [Fact]
    public void TheCheckEveryThirtySecondsFindsTheNewDay()
    {
        var model = Model();
        _app.Set("2026-10-12T23:59:50");
        Assert.Equal("2026-10-12", model.Period);

        _app.Advance(NotesModel.CheckInterval);

        Assert.Equal("2026-10-13", model.Period);
    }

    [Fact]
    public void ANewWeekShowsAnEmptyNote()
    {
        var model = Model(NoteScope.Week);
        model.Edit("Week 42");

        _app.Set("2026-10-19T09:00:00");
        model.Sync();

        Assert.Equal("2026-W43", model.Period);
        Assert.Equal("", model.Text);
        Assert.Equal("Week 42", _app.Store.NoteBody(NoteScope.Week, "2026-W42"));
    }

    [Fact]
    public void SyncInTheSamePeriodKeepsTheText()
    {
        var model = Model();
        model.Edit("Typing");

        model.Sync();

        Assert.Equal("Typing", model.Text);
        Assert.True(model.HasUnsavedEdit);
    }

    [Fact]
    public void AnExternalChangeShowsWhenThePersonIsNotEditing()
    {
        var model = Model();
        _app.Execute("INSERT INTO note (scope, period, body, updated_at) VALUES ('day', '2026-10-12', 'From sqlite3', '2026-10-12T09:01:00')");
        _app.Store.CheckForExternalChanges();

        model.Sync();

        Assert.Equal("From sqlite3", model.Text);
        Assert.False(model.HasUnsavedEdit);
    }

    [Fact]
    public void AnExternalChangeWaitsWhileThePersonIsEditing()
    {
        var model = Model();
        model.Edit("My draft");
        _app.Execute("INSERT INTO note (scope, period, body, updated_at) VALUES ('day', '2026-10-12', 'From sqlite3', '2026-10-12T09:01:00')");
        _app.Store.CheckForExternalChanges();

        model.Sync();
        Assert.Equal("My draft", model.Text);

        model.Flush();
        Assert.Equal("My draft", _app.Store.NoteBody(NoteScope.Day));
    }

    [Fact]
    public void AnEmptyTextSavesAsAnEmptyBodyAndTheRowStays()
    {
        _app.Store.SaveNote(NoteScope.Day, "Something");
        var model = Model();

        model.Edit("");
        model.Flush();

        Assert.Equal(["day|2026-10-12|"], Rows());
    }

    [Fact]
    public void AnEmptyTextOnANoteWithNoRowWritesNothing()
    {
        var model = Model();

        model.Edit("x");
        model.Edit("");
        model.Flush();

        Assert.Empty(Rows());
    }

    [Fact]
    public void AFailedWriteKeepsTheEditAndRaisesTheFlag()
    {
        var model = Model();
        _app.Execute("DROP TABLE note");

        model.Edit("Lost?");
        model.Flush();

        Assert.True(model.SaveFailed);
        Assert.True(model.HasUnsavedEdit);
        Assert.Equal("Lost?", model.Text);
    }
}

public sealed class PriorityNoteModelTests : IDisposable
{
    private readonly AppHarness _app = new("2026-10-12T09:00:00");

    public void Dispose() => _app.Dispose();

    private PriorityNoteModel Model(Priority priority) => _app.Own(new PriorityNoteModel(_app.Store, _app.Clock, priority.Id));

    private int Edited(Priority priority) => _app.Store.Events(priority.Id).Count(e => e.Type == PriorityEventType.Edited);

    private string? Note(Priority priority) => _app.Store.Find(priority.Id)?.Note;

    [Fact]
    public void AnEmptyOrBlankNoteStoresAsEmptyAndShowsNoIcon()
    {
        Assert.Equal("", PriorityNote.Stored(""));
        Assert.Equal("", PriorityNote.Stored("\n\t \n"));
        Assert.Equal(" a ", PriorityNote.Stored(" a "));
        Assert.Equal("Doc\n\nlink", PriorityNote.Stored("Doc\n\nlink"));
        Assert.False(PriorityNote.IsPresent("  \n "));
        Assert.True(PriorityNote.IsPresent("  a  "));
    }

    [Fact]
    public void TheModelStartsWithTheStoredNote()
    {
        var priority = _app.Store.Add("P", note: "Doc del brief.");

        Assert.Equal("Doc del brief.", Model(priority).Text);
    }

    [Fact]
    public void TypingThenWaitingSavesOnce()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);

        model.Text = "Hola";
        Assert.Equal("", Note(priority));
        Assert.True(model.HasUnsavedEdit);

        _app.Advance(PriorityNoteModel.SaveDelay);
        Assert.Equal("Hola", Note(priority));
        Assert.False(model.HasUnsavedEdit);
        Assert.False(model.SaveFailed);
        Assert.Equal(1, Edited(priority));
    }

    [Fact]
    public void TwoFastEditsSaveOnce()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);

        model.Edit("H");
        _app.AdvanceMs(300);
        model.Edit("Ho");
        _app.AdvanceMs(300);
        Assert.Equal("", Note(priority));

        _app.AdvanceMs(100);
        Assert.Equal("Ho", Note(priority));
        Assert.Equal(1, Edited(priority));
    }

    [Fact]
    public void AFlushOnCloseSavesAtOnceAndTheTimerWritesNothingMore()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);

        model.Edit("Closing the detail");
        model.Flush();
        Assert.Equal("Closing the detail", Note(priority));

        _app.AdvanceMs(400);
        Assert.Equal(1, Edited(priority));
    }

    [Fact]
    public void AFlushWithNoEditWritesNothing()
    {
        var priority = _app.Store.Add("P", note: "Same");

        Model(priority).Flush();

        Assert.Equal(0, Edited(priority));
    }

    [Fact]
    public void TextThatEqualsTheStoredNoteWritesNothing()
    {
        var priority = _app.Store.Add("P", note: "Same");
        var model = Model(priority);

        model.Edit("Same!");
        model.Edit("Same");
        model.Flush();

        Assert.Equal("Same", Note(priority));
        Assert.False(model.HasUnsavedEdit);
        Assert.Equal(0, Edited(priority));
    }

    [Fact]
    public void ABlankTextOnAnEmptyNoteWritesNothing()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);

        model.Edit("   \n ");
        model.Flush();

        Assert.Equal("", Note(priority));
        Assert.Equal(0, Edited(priority));
    }

    [Fact]
    public void ClearingTheTextWithOnlySpacesStoresAnEmptyNote()
    {
        var priority = _app.Store.Add("P", note: "Doc");
        var model = Model(priority);

        model.Edit("  \n ");
        model.Flush();

        Assert.Equal("", Note(priority));
        Assert.Equal(1, Edited(priority));
    }

    [Fact]
    public void ASaveKeepsTheOtherFieldsOfThePriority()
    {
        var priority = _app.Store.Add("Title", PriorityList.Week, PriorityLevel.High, "2026-10-14T10:00:00");
        var model = Model(priority);

        model.Edit("Note");
        model.Flush();

        var saved = _app.Store.Find(priority.Id)!;
        Assert.Equal(priority with { Note = "Note", UpdatedAt = saved.UpdatedAt }, saved);
    }

    [Fact]
    public void ADeletedPriorityDropsTheEditWithoutAnError()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);
        model.Edit("Lost");
        _app.Store.Delete(priority.Id);

        model.Flush();

        Assert.False(model.HasUnsavedEdit);
        Assert.False(model.SaveFailed);
    }

    [Fact]
    public void AFailedWriteKeepsTheEditAndRaisesTheFlag()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);
        _app.Execute("DROP TABLE priority_event");

        model.Edit("Lost?");
        model.Flush();

        Assert.True(model.SaveFailed);
        Assert.True(model.HasUnsavedEdit);
    }

    [Fact]
    public void AnExternalChangeShowsWhenThePersonIsNotEditing()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);
        _app.Execute("UPDATE priority SET note = 'From sqlite3'");
        _app.Store.CheckForExternalChanges();

        model.Sync();

        Assert.Equal("From sqlite3", model.Text);
        Assert.False(model.HasUnsavedEdit);
    }

    [Fact]
    public void AnExternalChangeWaitsWhileThePersonIsEditing()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);
        model.Edit("My draft");
        _app.Execute("UPDATE priority SET note = 'From sqlite3'");
        _app.Store.CheckForExternalChanges();

        model.Sync();
        Assert.Equal("My draft", model.Text);

        model.Flush();
        Assert.Equal("My draft", Note(priority));
    }

    [Fact]
    public void SyncKeepsTheSpacesTheNoteStoresAsEmpty()
    {
        var priority = _app.Store.Add("P");
        var model = Model(priority);
        model.Edit("  ");
        model.Flush();

        model.Sync();

        Assert.Equal("  ", model.Text);
    }
}
