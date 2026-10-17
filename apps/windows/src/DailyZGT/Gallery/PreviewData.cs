using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Theme;

namespace DailyZGT.Gallery;

// Real time that can be moved back while the demo rows are written, so the store logs "created yesterday",
// "done three days ago" and so on. After seeding the shift is zero and the clock is the wall clock. With a
// fixed moment the clock stands still on it, in UTC, so a rendered image does not depend on the day or the
// time zone of the machine.
internal sealed class ShiftedTime(DateTime? fixedAt = null) : TimeProvider
{
    public TimeSpan Shift { get; set; }

    public override TimeZoneInfo LocalTimeZone => fixedAt is null ? base.LocalTimeZone : TimeZoneInfo.Utc;

    public override DateTimeOffset GetUtcNow() =>
        (fixedAt is { } moment ? new DateTimeOffset(DateTime.SpecifyKind(moment, DateTimeKind.Utc)) : base.GetUtcNow()) + Shift;
}

internal sealed class PreviewMotion : IAnimationSource
{
    public bool AnimationsEnabled => !Motion.IsReduced;

    public event EventHandler? Changed;

    public void Set(bool reduced)
    {
        Motion.IsReduced = reduced;
        Changed?.Invoke(this, EventArgs.Empty);
    }
}

internal sealed class NoStartup(StartupStatus state = StartupStatus.Off) : IStartupService
{
    public StartupStatus State => state;

    public void Enable()
    {
    }

    public void Disable()
    {
    }
}

internal sealed class NoHotkey(CaptureShortcut? current = null) : ICaptureHotkey
{
    public CaptureShortcut? Current => current;

    public event EventHandler? Pressed
    {
        add { }
        remove { }
    }

    public ShortcutFailure? Start() => null;

    public void Set(CaptureShortcut shortcut)
    {
    }

    public void Clear()
    {
    }
}

// A PanelState on an in-memory store with rows of every kind the Priorities views draw. The readme set is
// the English demo of the README images: a stopped clock on Monday 12 October, the wording of the website
// demo, login on, the tray title on and the default shortcut.
internal sealed class PreviewData : IDisposable
{
    public static readonly DateTime ReadmeNow = new(2026, 10, 12, 10, 24, 0);

    private static readonly CaptureShortcut DefaultShortcut =
        new(ShortcutModifiers.Control | ShortcutModifiers.Alt | ShortcutModifiers.Shift, 'P');

    private readonly bool _readme;

    public PreviewData(SynchronizationContext? ui, bool readme = false)
    {
        _readme = readme;
        Time = new ShiftedTime(readme ? ReadmeNow : null);
        Store = AppStore.OpenInMemory(Time);
        Seed();
        Clock = new UiClock(Time, ui);
        Motion = new PreviewMotion();
        Policy = new MotionPolicy(Motion, TeclaTokens.Durations.Slow);
        var startup = new NoStartup(readme ? StartupStatus.On : StartupStatus.Off);
        var hotkey = new NoHotkey(readme ? DefaultShortcut : null);
        Panel = new PanelState(Store, Clock, Policy, new StartupSettings(startup), new ShortcutSettings(hotkey));
    }

    public ShiftedTime Time { get; }

    public AppStore Store { get; }

    public UiClock Clock { get; }

    public PreviewMotion Motion { get; }

    public MotionPolicy Policy { get; }

    public PanelState Panel { get; }

    public string ProposalId { get; private set; } = "";

    public string ContractId { get; private set; } = "";

    public void Dispose()
    {
        Panel.Dispose();
        Policy.Dispose();
        Clock.Dispose();
        Store.Dispose();
    }

    private void Seed()
    {
        if (_readme)
        {
            SeedReadme();
        }
        else
        {
            SeedPreview();
        }
    }

    private void SeedReadme()
    {
        var now = LocalTime.Now(Time);

        At(TimeSpan.FromDays(-1), () => Add("Tidy the desk", PriorityList.Today, PriorityLevel.Low));
        At(TimeSpan.Zero, () =>
        {
            var contract = Add("Review the Lima contract", PriorityList.Today, PriorityLevel.High, now.Date.AddHours(11).AddMinutes(30));
            ContractId = contract.Id;
            Store.SetNote(contract.Id, "Check clause 4 with legal before you sign.");
            var proposal = Add("Send the proposal", PriorityList.Today, PriorityLevel.High, now.Date.AddHours(13));
            ProposalId = proposal.Id;
            Store.SetNote(proposal.Id, "Use the new price list.");
            var first = Store.AddSubtask(proposal.Id, "Build the PDF")!;
            Store.AddSubtask(proposal.Id, "Check the prices");
            Store.AddSubtask(proposal.Id, "Send the email");
            Store.ToggleSubtask(first.Id);
            Add("Prepare Thursday's demo", PriorityList.Today, PriorityLevel.Medium, now.Date.AddHours(16));
            Done(Add("Call Marta", PriorityList.Today, PriorityLevel.Medium));
            Add("Plan the quarter", PriorityList.Week, PriorityLevel.Medium, now.Date.AddDays(4).AddHours(18));
            Add("Pay the hosting", PriorityList.Week, PriorityLevel.Low);
            Add("Write the sprint summary", PriorityList.Week, PriorityLevel.High, now.Date.AddDays(2).AddHours(17));
            Store.SaveNote(NoteScope.Day, "Call Marta before 5");
            Store.SaveNote(NoteScope.Week, "Close the Lima contract on Friday");
            Store.SetValue(AppStateKeys.TrayTitle, true);
        });
    }

    private void SeedPreview()
    {
        var now = LocalTime.Now(Time);

        At(TimeSpan.FromDays(-4), () =>
        {
            Done(Add("Llamar al banco", PriorityList.Today, PriorityLevel.Medium));
            Done(Add("Revisar el presupuesto", PriorityList.Week, PriorityLevel.Low));
        });
        At(TimeSpan.FromDays(-3), () =>
        {
            ContractId = Add("Revisar el contrato de Lima", PriorityList.Today, PriorityLevel.High, now.AddHours(-2)).Id;
            Done(Add("Comprar el regalo de Ana", PriorityList.Today, PriorityLevel.Low));
        });
        At(TimeSpan.FromDays(-1), () =>
        {
            Add("Ordenar el escritorio", PriorityList.Today, PriorityLevel.Low);
            Done(Add("Pagar la luz", PriorityList.Today, PriorityLevel.Medium));
        });
        At(TimeSpan.Zero, () =>
        {
            var proposal = Add("Enviar la propuesta a Marta", PriorityList.Today, PriorityLevel.High, now.AddMinutes(36));
            ProposalId = proposal.Id;
            Store.SetNote(proposal.Id, "Revisar los precios antes de enviar.");
            var first = Store.AddSubtask(proposal.Id, "Revisar los precios")!;
            Store.AddSubtask(proposal.Id, "Adjuntar el contrato");
            Store.AddSubtask(proposal.Id, "Enviar por correo");
            Store.ToggleSubtask(first.Id);
            Add("Preparar la demo del jueves", PriorityList.Today, PriorityLevel.Medium, now.Date.AddDays(1).AddHours(16));
            Done(Add("Responder los correos", PriorityList.Today, PriorityLevel.Medium));
            Add("Planear la semana", PriorityList.Week, PriorityLevel.High);
            Add("Leer el informe trimestral", PriorityList.Week, PriorityLevel.Medium, now.AddDays(3));
            Store.SetValue(AppStateKeys.DoneOpen, true);
        });
    }

    private void At(TimeSpan shift, Action write)
    {
        Time.Shift = shift;
        write();
        Time.Shift = TimeSpan.Zero;
    }

    private Priority Add(string title, PriorityList list, PriorityLevel level, DateTime? due = null) =>
        ((AddOutcome.Added)Store.AddPriority(title, list, level, due)).Priority;

    private void Done(Priority priority) => Store.MarkDone(priority.Id);
}
