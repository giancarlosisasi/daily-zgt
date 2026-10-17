using System.Globalization;

namespace DailyZGT.Core.Localization;

// Every user-facing string of the app, in one language. A missing translation is a compile error because
// every member is `required`. Members that take arguments are delegates, because word order differs.
public sealed class Texts
{
    public static readonly Texts Es = SpanishTexts.Create();
    public static readonly Texts En = EnglishTexts.Create();
    public static readonly Texts Pt = PortugueseTexts.Create();

    public static IReadOnlyList<Texts> All { get; } = [Es, En, Pt];

    public static Texts For(AppLanguage language) =>
        language switch
        {
            AppLanguage.Es => Es,
            AppLanguage.En => En,
            AppLanguage.Pt => Pt,
            _ => throw new ArgumentOutOfRangeException(nameof(language), language, null),
        };

    public required AppLanguage Language { get; init; }

    // Date vocabulary. Index 0 is Sunday for the weekday tables and January for the month tables.
    public required IReadOnlyList<string> Weekdays { get; init; }
    public required IReadOnlyList<string> ShortWeekdays { get; init; }
    public required IReadOnlyList<string> Months { get; init; }
    public required IReadOnlyList<string> ShortMonths { get; init; }

    // `Lunes 12 oct`, `Monday Oct 12`, `Segunda 12 out`.
    public required Func<DateTime, string> DayLabel { get; init; }

    // `Semana 42 · 12–18 oct`, `Semana 40 · 28 sep–4 oct`. Takes any date of the ISO week.
    public required Func<DateTime, string> WeekLabel { get; init; }

    // The header of the date picker, for example `Octubre 2026`.
    public required Func<DateTime, string> MonthTitle { get; init; }

    // F01. Tray.
    public required string TrayMenuOpen { get; init; }
    public required string TrayMenuQuit { get; init; }

    // F02. Panel tabs, scope tabs, errors.
    public required string TabPriorities { get; init; }
    public required string TabNotes { get; init; }
    public required string ScopeToday { get; init; }
    public required string ScopeWeek { get; init; }
    public required string DatabaseOpenFailed { get; init; }
    public required Func<string, string> BackTo { get; init; }

    // F03. Empty states.
    public required string EmptyAllDone { get; init; }
    public required string EmptyNothingPending { get; init; }

    // F04. Row.
    public required string ShowSubtasks { get; init; }
    public required string HideSubtasks { get; init; }
    public required string SubtasksLabel { get; init; }
    public required string StateExpanded { get; init; }
    public required string StateCollapsed { get; init; }
    public required string HasNote { get; init; }
    public required string RemoveRow { get; init; }
    public required Func<string, string> MarkDoneCheckbox { get; init; }
    public required string ListSaveFailed { get; init; }

    // F05. New priority form. The labels also name the rows of the detail box (F09).
    public required string NewPriority { get; init; }
    public required string TitlePlaceholder { get; init; }
    public required string LabelPriority { get; init; }
    public required string LabelDue { get; init; }
    public required string LabelList { get; init; }
    public required string LabelRepeat { get; init; }
    public required string LabelAlert { get; init; }
    public required string LevelHigh { get; init; }
    public required string LevelMedium { get; init; }
    public required string LevelLow { get; init; }
    public required string LevelHighName { get; init; }
    public required string LevelMediumName { get; init; }
    public required string LevelLowName { get; init; }
    public required string NoDate { get; init; }
    public required string ClearDate { get; init; }
    public required string DueNote { get; init; }
    public required string Add { get; init; }
    public required string Cancel { get; init; }
    public required string PickerPreviousMonth { get; init; }
    public required string PickerNextMonth { get; init; }
    public required string PickerHour { get; init; }
    public required string PickerMinute { get; init; }
    public required string PickerDone { get; init; }

    // F06.
    public required string TodayLimitMessage { get; init; }

    // F07. Confirm and undo bars.
    public required string ConfirmDoneTitle { get; init; }
    public required string ConfirmDone { get; init; }
    public required string ConfirmName { get; init; }
    public required string MarkDoneButton { get; init; }
    public required string Undo { get; init; }
    public required Func<string, string> UndoLine { get; init; }

    // `Queda 1 subtarea abierta.` for 1, `Quedan N subtareas abiertas.` for more.
    public required Func<int, string> SubtasksLeft { get; init; }

    // F08. Done and history.
    public required Func<int, string> DoneHeader { get; init; }
    public required string DoneMark { get; init; }
    public required string Reopen { get; init; }
    public required string HistoryTitle { get; init; }
    public required string HistoryBack { get; init; }
    public required string HistoryEmpty { get; init; }
    public required string Yesterday { get; init; }

    // F09. Detail view.
    public required string DetailDelete { get; init; }
    public required string TitleField { get; init; }
    public required string StateOpen { get; init; }
    public required string StateDone { get; init; }
    public required Func<int, int, string> SubtasksChip { get; init; }
    public required string RepeatNo { get; init; }
    public required string RepeatDaily { get; init; }
    public required string AlertLine { get; init; }
    public required string AlertLineNoDate { get; init; }
    public required string SectionSubtasks { get; init; }
    public required string SectionNotes { get; init; }
    public required string CreatedToday { get; init; }

    // `Creada vie 9 oct · 16:00`.
    public required Func<DateTime, string> CreatedOn { get; init; }

    // F10. Subtasks.
    public required string SubtaskPlaceholder { get; init; }
    public required string NewSubtask { get; init; }

    // F11. Note of a priority.
    public required string NotePlaceholder { get; init; }
    public required string NoteSaveFailed { get; init; }

    // F12. Due chip.
    public required string DueOverdue { get; init; }
    public required Func<int, string> DueInMinutes { get; init; }
    public required Func<int, int, string> DueInHours { get; init; }
    public required Func<DateTime, string> DueToday { get; init; }
    public required Func<DateTime, string> DueOtherDay { get; init; }

    // F13. Since chip.
    public required string SinceYesterday { get; init; }
    public required Func<DateTime, string> SinceDay { get; init; }

    // F15. Alerts.
    public required string AlertBeforeTitle { get; init; }
    public required string AlertOverdueTitle { get; init; }
    public required string AlertDuePrefix { get; init; }
    public required string AlertTestBody { get; init; }
    public required string AlertOpen { get; init; }
    public required string AlertSnooze { get; init; }
    public required string TestAlert { get; init; }
    public required string AlertsOff { get; init; }
    public required string OpenSettings { get; init; }

    // F16. Notes of the day and of the week.
    public required string NotesToday { get; init; }
    public required string NotesWeek { get; init; }
    public required string NotesPlaceholder { get; init; }
    public required string NotesSavedHint { get; init; }

    // F17. Capture window.
    public required string CaptureTitle { get; init; }
    public required string CaptureHint { get; init; }
    public required string CaptureSaveFailed { get; init; }

    // F18. Settings. Windows copy, see ARCHITECTURE.md.
    public required string SettingsTitle { get; init; }
    public required string SettingsClose { get; init; }
    public required string StateOn { get; init; }
    public required string StateOff { get; init; }
    public required string LoginTitle { get; init; }
    public required string LoginDetail { get; init; }
    public required string LoginApproval { get; init; }
    public required string LoginFailed { get; init; }
    public required string TodayLimitTitle { get; init; }
    public required string TodayLimitDetail { get; init; }
    public required string NextPriorityTitle { get; init; }
    public required string NextPriorityDetail { get; init; }
    public required string ShortcutTitle { get; init; }
    public required string ShortcutDetail { get; init; }
    public required string ShortcutClearedDetail { get; init; }
    public required string ShortcutEmpty { get; init; }
    public required string ShortcutRecording { get; init; }
    public required string ShortcutClear { get; init; }
    public required string ShortcutNeedsModifier { get; init; }
    public required string ShortcutTaken { get; init; }
    public required string KeyCtrl { get; init; }
    public required string KeyAlt { get; init; }
    public required string KeyShift { get; init; }
    public required string KeyWin { get; init; }

    // F19. Footer.
    public required Func<int, int, string> FooterToday { get; init; }
    public required Func<int, int, string> FooterWeek { get; init; }
    public required string Quit { get; init; }

    // Wording that does not change with the language.

    public static string Clock(DateTime time) => $"{time.Hour:00}:{time.Minute:00}";

    public string Weekday(DateTime date) => Weekdays[(int)date.DayOfWeek];

    public string ShortWeekday(DateTime date) => ShortWeekdays[(int)date.DayOfWeek];

    public string ShortMonth(DateTime date) => ShortMonths[date.Month - 1];

    // F01. `Daily ZGT · 3`.
    public string TrayTooltip(int openCount) => string.Create(CultureInfo.InvariantCulture, $"Daily ZGT · {openCount}");

    // F02. `Hoy · 3`.
    public string TodayTab(int openCount) => string.Create(CultureInfo.InvariantCulture, $"{ScopeToday} · {openCount}");

    public string WeekTab(int openCount) => string.Create(CultureInfo.InvariantCulture, $"{ScopeWeek} · {openCount}");

    // F04. `1/3`.
    public string SubtaskRatio(int done, int total) => string.Create(CultureInfo.InvariantCulture, $"{done}/{total}");

    // F08. Group title of the history: `Ayer`, or a day label such as `Lunes 12 oct`.
    public string HistoryGroupTitle(DateTime day, DateTime now)
    {
        if (day.Date == now.Date)
        {
            return ScopeToday;
        }

        return day.Date == now.Date.AddDays(-1) ? Yesterday : DayLabel(day);
    }

    // F15. `Vence ` plus the chip text with its first letter in lowercase. A weekday chip keeps its case.
    public string AlertDueTitle(string chipText)
    {
        var keepsCase = ShortWeekdays.Any(day => chipText.StartsWith(day + " ", StringComparison.Ordinal));
        var text = chipText.Length == 0 || keepsCase
            ? chipText
            : char.ToLowerInvariant(chipText[0]) + chipText[1..];
        return AlertDuePrefix + text;
    }
}

internal readonly record struct WeekSpan(int Number, DateTime First, DateTime Last)
{
    public static WeekSpan Containing(DateTime date)
    {
        var first = date.Date.AddDays(-(((int)date.DayOfWeek + 6) % 7));
        return new WeekSpan(ISOWeek.GetWeekOfYear(date), first, first.AddDays(6));
    }

    public bool CrossesMonths => First.Month != Last.Month;
}
