namespace DailyZGT.Core.Localization;

// Wording from apps/website/i18n.json (`demo.*`) first. The rest follows the same voice: sentence case, short.
internal static class EnglishTexts
{
    private static readonly string[] Weekdays =
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

    private static readonly string[] ShortWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    private static readonly string[] Months =
        ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

    private static readonly string[] ShortMonths =
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    public static Texts Create() => new()
    {
        Language = AppLanguage.En,

        Weekdays = Weekdays,
        ShortWeekdays = ShortWeekdays,
        Months = Months,
        ShortMonths = ShortMonths,
        DayLabel = date => $"{Weekdays[(int)date.DayOfWeek]} {ShortMonths[date.Month - 1]} {date.Day}",
        WeekLabel = date =>
        {
            var week = WeekSpan.Containing(date);
            var first = $"{ShortMonths[week.First.Month - 1]} {week.First.Day}";
            var last = week.CrossesMonths ? $"{ShortMonths[week.Last.Month - 1]} {week.Last.Day}" : $"{week.Last.Day}";
            return $"Week {week.Number} · {first}–{last}";
        },
        MonthTitle = date => $"{Months[date.Month - 1]} {date.Year}",

        TrayMenuOpen = "Open",
        TrayMenuQuit = "Quit",

        TabPriorities = "Priorities",
        TabNotes = "Notes",
        ScopeToday = "Today",
        ScopeWeek = "Week",
        DatabaseOpenFailed = "Could not open the database.",
        BackTo = list => $"Back to {list}",

        EmptyAllDone = "All done in this list",
        EmptyNothingPending = "Nothing pending in this list.",

        ShowSubtasks = "Show subtasks",
        HideSubtasks = "Hide subtasks",
        SubtasksLabel = "Subtasks",
        StateExpanded = "expanded",
        StateCollapsed = "collapsed",
        HasNote = "Has notes",
        RemoveRow = "Remove",
        MarkDoneCheckbox = title => $"Mark as done: {title}",
        ListSaveFailed = "Could not save the change.",

        NewPriority = "New priority",
        TitlePlaceholder = "What is the priority?",
        LabelPriority = "Priority",
        LabelDue = "Due time",
        LabelList = "List",
        LabelRepeat = "Repeat",
        LabelAlert = "Alert",
        LevelHigh = "High",
        LevelMedium = "Medium",
        LevelLow = "Low",
        LevelHighName = "High priority",
        LevelMediumName = "Medium priority",
        LevelLowName = "Low priority",
        NoDate = "No due time",
        ClearDate = "Clear due time",
        DueNote = "Alert with sound 30 min before and at the due time",
        Add = "Add",
        Cancel = "Cancel",
        PickerPreviousMonth = "Previous month",
        PickerNextMonth = "Next month",
        PickerHour = "Hour",
        PickerMinute = "Minute",
        PickerDone = "Done",

        TodayLimitMessage = "Today already has 5 open priorities.",

        ConfirmDoneTitle = "Mark as done?",
        ConfirmDone = "Done",
        ConfirmName = "Confirm",
        MarkDoneButton = "Mark as done",
        Undo = "Undo",
        UndoLine = title => $"Done: {title}",
        SubtasksLeft = count => count == 1 ? "1 subtask is still open." : $"{count} subtasks are still open.",

        DoneHeader = count => $"Completed ({count})",
        DoneMark = "Done",
        Reopen = "Reopen",
        HistoryTitle = "History",
        HistoryBack = "Back to Completed",
        HistoryEmpty = "Nothing in the history.",
        Yesterday = "Yesterday",

        DetailDelete = "Delete priority",
        TitleField = "Title",
        StateOpen = "Pending",
        StateDone = "Done",
        SubtasksChip = (done, total) => $"{done}/{total} subtasks",
        RepeatNo = "No",
        RepeatDaily = "Every day",
        AlertLine = "30 min before and at the due time",
        AlertLineNoDate = "No due time, no alert",
        SectionSubtasks = "SUBTASKS",
        SectionNotes = "NOTES",
        CreatedToday = "Created today",
        CreatedOn = date =>
            $"Created {ShortWeekdays[(int)date.DayOfWeek]} {ShortMonths[date.Month - 1]} {date.Day} · {Texts.Clock(date)}",

        SubtaskPlaceholder = "Add a subtask and press Enter",
        NewSubtask = "New subtask",

        NotePlaceholder = "Context, links, what is missing",
        NoteSaveFailed = "Could not save the note.",

        DueOverdue = "Overdue",
        DueInMinutes = minutes => $"In {minutes} min",
        DueInHours = (hours, minutes) => $"In {hours} h {minutes} min",
        DueToday = due => $"Today {Texts.Clock(due)}",
        DueOtherDay = due => $"{ShortWeekdays[(int)due.DayOfWeek]} {Texts.Clock(due)}",

        SinceYesterday = "From yesterday",
        SinceDay = entered => $"Since {ShortWeekdays[(int)entered.DayOfWeek]} {entered.Day}",

        AlertOverdueTitle = "Priority overdue",
        AlertDuePrefix = "Due ",
        AlertTestBody = "Check your list for today",
        AlertOpen = "Open",
        AlertSnooze = "Snooze 15 min",
        TestAlert = "Test alert",
        AlertsOff = "Alerts are turned off.",
        OpenSettings = "Open settings",

        NotesToday = "Notes for today",
        NotesWeek = "Notes for the week",
        NotesPlaceholder = "Write a note",
        NotesSavedHint = "Saved as you type.",

        CaptureTitle = "New priority",
        CaptureHint = "Enter adds. Escape closes.",
        CaptureSaveFailed = "Could not save the priority.",

        SettingsTitle = "Settings",
        SettingsClose = "Close settings",
        StateOn = "On",
        StateOff = "Off",
        LoginTitle = "Open at login",
        LoginDetail = "Opens Daily ZGT when you sign in to your computer.",
        LoginApproval = "Your approval is missing in Settings.",
        LoginFailed = "Windows did not accept the change.",
        TodayLimitTitle = "Maximum 5 open priorities in Today",
        TodayLimitDetail = "With 5 open in Today, you cannot add or move another one to Today.",
        NextPriorityTitle = "Next priority in the taskbar",
        NextPriorityDetail = "Shows the title of the first open priority in Today when you hover over the icon.",
        ShortcutTitle = "Global shortcut",
        ShortcutDetail = "Opens the capture window from any app.",
        ShortcutClearedDetail = "No shortcut: the capture window does not open from other apps.",
        ShortcutEmpty = "No shortcut",
        ShortcutRecording = "Press a shortcut",
        ShortcutClear = "Clear shortcut",
        ShortcutNeedsModifier = "A shortcut needs Ctrl, Alt, Shift or Win, or a function key.",
        ShortcutTaken = "The system or another app already uses these keys.",
        KeyCtrl = "Ctrl",
        KeyAlt = "Alt",
        KeyShift = "Shift",
        KeyWin = "Win",
        KeyBackspace = "Backspace",
        KeyTab = "Tab",
        KeyEnter = "Enter",
        KeyPause = "Pause",
        KeyCapsLock = "Caps Lock",
        KeyEscape = "Esc",
        KeySpace = "Space",
        KeyPageUp = "Page Up",
        KeyPageDown = "Page Down",
        KeyEnd = "End",
        KeyHome = "Home",
        KeyLeft = "Left",
        KeyUp = "Up",
        KeyRight = "Right",
        KeyDown = "Down",
        KeyPrintScreen = "Print Screen",
        KeyInsert = "Insert",
        KeyDelete = "Delete",
        KeyNumpad = digit => $"Num {digit}",
        KeyOther = code => $"Key {code:X2}",

        FooterToday = (done, total) => $"{done} of {total} done today",
        FooterWeek = (done, total) => $"{done} of {total} done this week",
        Quit = "Quit",
    };
}
