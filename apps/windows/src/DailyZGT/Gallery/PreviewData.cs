using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Theme;

namespace DailyZGT.Gallery;

// Real time that can be moved back while the demo rows are written, so the store logs "created yesterday",
// "done three days ago" and so on. After seeding the shift is zero and the clock is the wall clock.
internal sealed class ShiftedTime : TimeProvider
{
    public TimeSpan Shift { get; set; }

    public override DateTimeOffset GetUtcNow() => base.GetUtcNow() + Shift;
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

internal sealed class NoStartup : IStartupService
{
    public StartupStatus State => StartupStatus.Off;

    public void Enable()
    {
    }

    public void Disable()
    {
    }
}

internal sealed class NoHotkey : ICaptureHotkey
{
    public CaptureShortcut? Current => null;

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

// A PanelState on an in-memory store with rows of every kind the Priorities views draw.
internal sealed class PreviewData : IDisposable
{
    public PreviewData(SynchronizationContext? ui)
    {
        Time = new ShiftedTime();
        Store = AppStore.OpenInMemory(Time);
        Seed();
        Clock = new UiClock(Time, ui);
        Motion = new PreviewMotion();
        Policy = new MotionPolicy(Motion, TeclaTokens.Durations.Slow);
        Panel = new PanelState(Store, Clock, Policy, new StartupSettings(new NoStartup()), new ShortcutSettings(new NoHotkey()));
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
