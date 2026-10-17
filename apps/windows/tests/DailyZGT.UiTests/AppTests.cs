namespace DailyZGT.UiTests;

[Trait("Category", "UI")]
public sealed class NotesTests : IDisposable
{
    private readonly AppSession _app = AppSession.Start();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void TheNoteOfTheDayIsThereAfterSalirAndANewLaunch()
    {
        _app.Click("TabNotes");
        _app.Click("NotesBox");
        _app.Type("Llevar el cargador");

        _app.Restart();

        _app.Expect("Llevar el cargador", () => _app.Value("NotesBox"));
    }
}

[Trait("Category", "UI")]
public sealed class TodayLimitTests : IDisposable
{
    private readonly AppSession _app = AppSession.Start();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void TheCaptureWindowRefusesASixthPriorityForHoyAndStaysOpen()
    {
        _app.Click("SettingsButton");
        _app.Invoke("SettingTodayLimit");
        _app.Click("SettingsBack");
        foreach (var title in new[] { "Uno", "Dos", "Tres", "Cuatro", "Cinco" })
        {
            _app.AddPriority(title);
        }

        _app.Expect("Hoy · 5", () => _app.Name("ScopeToday"));

        _app.Launch("--show-capture");
        _app.Click("CaptureField");
        _app.Type("Seis");
        _app.Key("enter");

        _app.Expect("Hoy ya tiene 5 prioridades abiertas.", () => _app.Name("CaptureNotice"));
        Assert.NotNull(_app.Find("CaptureWindow"));
        _app.Key("escape");
        _app.WaitGone("CaptureWindow");
    }
}

[Trait("Category", "UI")]
public sealed class LanguageTests : IDisposable
{
    private readonly AppSession _app = AppSession.Start("en");

    public void Dispose() => _app.Dispose();

    [Fact]
    public void InEnglishThePanelSaysTodayAndTheFooterCountsInEnglish()
    {
        _app.Expect("Today · 0", () => _app.Name("ScopeToday"));
        _app.Expect("0 of 0 done today", () => _app.Name("FooterSummary"));
    }
}
