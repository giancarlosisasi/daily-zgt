namespace DailyZGT.UiTests;

// A click in the due date picker once hid the panel and gave the focus to the app behind it. The dates here
// are a month back, so the app schedules no toast for them.
[Trait("Category", "UI")]
public sealed class DuePickerTests : IDisposable
{
    private readonly AppSession _app = AppSession.Start();

    public void Dispose() => _app.Dispose();

    [Fact]
    public void PickingADateInTheDetailViewKeepsThePanelOpenAndInFront()
    {
        _app.AddPriority("Pagar la renta");
        var id = _app.RowId("Pagar la renta");
        _app.Click("RowTitle_" + id);

        PickADateLastMonth();

        _app.Wait("DueClear");
        _app.Click("DetailBack");
        _app.ExpectText("PriorityRow_" + id, "Vencida");
    }

    [Fact]
    public void PickingADateInTheFormKeepsThePanelOpenAndInFront()
    {
        _app.Click("NewPriorityButton");
        _app.Click("NewPriorityTitle");
        _app.Type("Renovar el pasaporte");

        PickADateLastMonth();

        _app.Click("AddButton");
        var id = _app.RowId("Renovar el pasaporte");
        _app.ExpectText("PriorityRow_" + id, "Vencida");
    }

    private void PickADateLastMonth()
    {
        _app.Click("DueButton");
        _app.Click("PickerPreviousMonth");
        _app.Click("PickerDone");
        _app.WaitGone("PickerDone");

        Assert.NotNull(_app.Find("PanelWindow"));
        _app.Expect(true, _app.OwnsForeground);
    }
}
