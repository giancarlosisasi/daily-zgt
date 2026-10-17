namespace DailyZGT.UiTests;

[Trait("Category", "UI")]
public sealed class PriorityListTests : IDisposable
{
    private readonly AppSession _app = AppSession.Start();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void ThreePrioritiesFromTheFormShowInLevelOrder()
    {
        _app.AddPriority("Comprar pan", "LevelLow");
        _app.AddPriority("Enviar el contrato", "LevelHigh");
        _app.AddPriority("Llamar a Marta", "LevelMedium");

        _app.Expect(
            "Enviar el contrato | Llamar a Marta | Comprar pan",
            () => string.Join(" | ", _app.FindAll("PriorityRow_").Select(row => row.Current.Name)));
        _app.Expect("Hoy · 3", () => _app.Name("ScopeToday"));
        _app.Expect("0 de 3 hechas hoy", () => _app.Name("FooterSummary"));
    }

    [Fact]
    public void ConfirmingADoneShowsTheUndoBarAndDeshacerBringsTheRowBack()
    {
        _app.AddPriority("Comprar pan");
        _app.AddPriority("Enviar el contrato");
        _app.AddPriority("Llamar a Marta");
        var id = _app.RowId("Enviar el contrato");

        _app.Click("RowCheckbox_" + id);
        _app.Click("ConfirmDone");

        _app.Expect("Hecha: Enviar el contrato", () => _app.Name("UndoText"));
        _app.Expect("1 de 3 hechas hoy", () => _app.Name("FooterSummary"));
        _app.WaitGone("PriorityRow_" + id);

        _app.Click("UndoButton");

        _app.Wait("PriorityRow_" + id);
        _app.Expect("0 de 3 hechas hoy", () => _app.Name("FooterSummary"));
        _app.Expect("Hoy · 3", () => _app.Name("ScopeToday"));
    }

    [Fact]
    public void SubtasksAddedInTheDetailViewShowAsProgressOnTheRow()
    {
        _app.AddPriority("Preparar la reunión");
        var id = _app.RowId("Preparar la reunión");

        _app.Click("RowTitle_" + id);
        _app.Click("SubtaskField");
        _app.Type("Reservar la sala");
        _app.Key("enter");
        _app.Type("Enviar la agenda");
        _app.Key("enter");
        _app.Expect(2, () => _app.FindAll("Subtask_").Count);
        _app.Click("DetailBack");

        _app.ExpectText("PriorityRow_" + id, "0/2");
    }
}
