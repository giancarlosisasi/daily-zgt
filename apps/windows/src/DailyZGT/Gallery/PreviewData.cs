using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
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

// The words of the readme demo in one language. The titles and the two notes of the day and the week are
// the website demo (demo.seed.* and demo.note.* in apps/website/i18n.json).
internal sealed class DemoWords
{
    public required string Desk { get; init; }

    public required string Contract { get; init; }

    public required string ContractNote { get; init; }

    public required string Proposal { get; init; }

    public required string ProposalNote { get; init; }

    public required string Pdf { get; init; }

    public required string Prices { get; init; }

    public required string Email { get; init; }

    public required string Demo { get; init; }

    public required string CallMarta { get; init; }

    public required string Quarter { get; init; }

    public required string Hosting { get; init; }

    public required string Sprint { get; init; }

    public required string DayNote { get; init; }

    public required string WeekNote { get; init; }

    public required string CaptureTitle { get; init; }

    public required string NewTitle { get; init; }

    public static DemoWords For(AppLanguage language) => language switch
    {
        AppLanguage.Es => new()
        {
            Desk = "Ordenar el escritorio",
            Contract = "Revisar el contrato de Lima",
            ContractNote = "Revisar la cláusula 4 con legal antes de firmar.",
            Proposal = "Enviar la propuesta",
            ProposalNote = "Usar la nueva lista de precios.",
            Pdf = "Armar el PDF",
            Prices = "Revisar los precios",
            Email = "Mandar el correo",
            Demo = "Preparar la demo del jueves",
            CallMarta = "Llamar a Marta",
            Quarter = "Planear el trimestre",
            Hosting = "Pagar el hosting",
            Sprint = "Escribir el resumen del sprint",
            DayNote = "Llamar a Marta antes de las 5",
            WeekNote = "Cerrar el contrato de Lima el viernes",
            CaptureTitle = "Responder el correo de Marta",
            NewTitle = "Reservar la sala para el viernes",
        },
        AppLanguage.Pt => new()
        {
            Desk = "Organizar a mesa",
            Contract = "Revisar o contrato de Lima",
            ContractNote = "Ver a cláusula 4 com o jurídico antes de assinar.",
            Proposal = "Enviar a proposta",
            ProposalNote = "Usar a nova tabela de preços.",
            Pdf = "Montar o PDF",
            Prices = "Revisar os preços",
            Email = "Enviar o e-mail",
            Demo = "Preparar a demo de quinta",
            CallMarta = "Ligar para a Marta",
            Quarter = "Planejar o trimestre",
            Hosting = "Pagar a hospedagem",
            Sprint = "Escrever o resumo da sprint",
            DayNote = "Ligar para a Marta antes das 17h",
            WeekNote = "Fechar o contrato de Lima na sexta",
            CaptureTitle = "Responder o e-mail da Marta",
            NewTitle = "Reservar a sala para sexta",
        },
        _ => new()
        {
            Desk = "Tidy the desk",
            Contract = "Review the Lima contract",
            ContractNote = "Check clause 4 with legal before you sign.",
            Proposal = "Send the proposal",
            ProposalNote = "Use the new price list.",
            Pdf = "Build the PDF",
            Prices = "Check the prices",
            Email = "Send the email",
            Demo = "Prepare Thursday's demo",
            CallMarta = "Call Marta",
            Quarter = "Plan the quarter",
            Hosting = "Pay the hosting",
            Sprint = "Write the sprint summary",
            DayNote = "Call Marta before 5",
            WeekNote = "Close the Lima contract on Friday",
            CaptureTitle = "Reply to Marta's email",
            NewTitle = "Book the room for Friday",
        },
    };
}

// A PanelState on an in-memory store with rows of every kind the Priorities views draw. The readme set is
// the demo of the README and docs images, in the language of UiText.Current: a stopped clock on Monday
// 12 October, the wording of the website demo, login on, the tray title on and the default shortcut.
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
        var words = DemoWords.For(UiText.Current.Language);

        At(TimeSpan.FromDays(-1), () => Add(words.Desk, PriorityList.Today, PriorityLevel.Low));
        At(TimeSpan.Zero, () =>
        {
            var contract = Add(words.Contract, PriorityList.Today, PriorityLevel.High, now.Date.AddHours(11).AddMinutes(30));
            ContractId = contract.Id;
            Store.SetNote(contract.Id, words.ContractNote);
            var proposal = Add(words.Proposal, PriorityList.Today, PriorityLevel.High, now.Date.AddHours(13));
            ProposalId = proposal.Id;
            Store.SetNote(proposal.Id, words.ProposalNote);
            var first = Store.AddSubtask(proposal.Id, words.Pdf)!;
            Store.AddSubtask(proposal.Id, words.Prices);
            Store.AddSubtask(proposal.Id, words.Email);
            Store.ToggleSubtask(first.Id);
            Add(words.Demo, PriorityList.Today, PriorityLevel.Medium, now.Date.AddHours(16));
            Done(Add(words.CallMarta, PriorityList.Today, PriorityLevel.Medium));
            Add(words.Quarter, PriorityList.Week, PriorityLevel.Medium, now.Date.AddDays(4).AddHours(18));
            Add(words.Hosting, PriorityList.Week, PriorityLevel.Low);
            Add(words.Sprint, PriorityList.Week, PriorityLevel.High, now.Date.AddDays(2).AddHours(17));
            Store.SaveNote(NoteScope.Day, words.DayNote);
            Store.SaveNote(NoteScope.Week, words.WeekNote);
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
