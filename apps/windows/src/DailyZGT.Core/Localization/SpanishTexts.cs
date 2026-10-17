namespace DailyZGT.Core.Localization;

// The Spanish text is exactly what docs/features.md writes, with the Windows copy of ARCHITECTURE.md.
internal static class SpanishTexts
{
    private static readonly string[] Weekdays =
        ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];

    private static readonly string[] ShortWeekdays = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];

    private static readonly string[] Months =
        ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];

    private static readonly string[] ShortMonths =
        ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

    public static Texts Create() => new()
    {
        Language = AppLanguage.Es,

        Weekdays = Weekdays,
        ShortWeekdays = ShortWeekdays,
        Months = Months,
        ShortMonths = ShortMonths,
        DayLabel = date => $"{Weekdays[(int)date.DayOfWeek]} {date.Day} {ShortMonths[date.Month - 1]}",
        WeekLabel = date =>
        {
            var week = WeekSpan.Containing(date);
            var last = $"{week.Last.Day} {ShortMonths[week.Last.Month - 1]}";
            var first = week.CrossesMonths ? $"{week.First.Day} {ShortMonths[week.First.Month - 1]}" : $"{week.First.Day}";
            return $"Semana {week.Number} · {first}–{last}";
        },
        MonthTitle = date => $"{Months[date.Month - 1]} {date.Year}",

        TrayMenuOpen = "Abrir",
        TrayMenuQuit = "Salir",

        TabPriorities = "Prioridades",
        TabNotes = "Notas",
        ScopeToday = "Hoy",
        ScopeWeek = "Semana",
        DatabaseOpenFailed = "No se pudo abrir la base de datos.",
        BackTo = list => $"Volver a {list}",

        EmptyAllDone = "Todo listo en esta lista",
        EmptyNothingPending = "Nada pendiente en esta lista.",

        ShowSubtasks = "Mostrar subtareas",
        HideSubtasks = "Ocultar subtareas",
        SubtasksLabel = "Subtareas",
        StateExpanded = "expandido",
        StateCollapsed = "colapsado",
        HasNote = "Tiene notas",
        RemoveRow = "Quitar",
        MarkDoneCheckbox = title => $"Marcar como hecha: {title}",
        ListSaveFailed = "No se pudo guardar el cambio.",

        NewPriority = "Nueva prioridad",
        TitlePlaceholder = "¿Qué es prioritario?",
        LabelPriority = "Prioridad",
        LabelDue = "Fecha límite",
        LabelList = "Lista",
        LabelRepeat = "Repetir",
        LabelAlert = "Alerta",
        LevelHigh = "Alta",
        LevelMedium = "Media",
        LevelLow = "Baja",
        LevelHighName = "Prioridad alta",
        LevelMediumName = "Prioridad media",
        LevelLowName = "Prioridad baja",
        NoDate = "Sin fecha",
        ClearDate = "Quitar fecha",
        DueNote = "Alerta con sonido 30 min antes y al vencer",
        Add = "Añadir",
        Cancel = "Cancelar",
        PickerPreviousMonth = "Mes anterior",
        PickerNextMonth = "Mes siguiente",
        PickerHour = "Hora",
        PickerMinute = "Minuto",
        PickerDone = "Listo",

        TodayLimitMessage = "Hoy ya tiene 5 prioridades abiertas.",

        ConfirmDoneTitle = "¿Marcar como hecha?",
        ConfirmDone = "Hecha",
        ConfirmName = "Confirmar",
        MarkDoneButton = "Marcar como hecha",
        Undo = "Deshacer",
        UndoLine = title => $"Hecha: {title}",
        SubtasksLeft = count => count == 1 ? "Queda 1 subtarea abierta." : $"Quedan {count} subtareas abiertas.",

        DoneHeader = count => $"Hechas ({count})",
        DoneMark = "Hecha",
        Reopen = "Regresar",
        HistoryTitle = "Historial",
        HistoryBack = "Volver a Hechas",
        HistoryEmpty = "Nada en el historial.",
        Yesterday = "Ayer",

        DetailDelete = "Eliminar prioridad",
        TitleField = "Título",
        StateOpen = "Pendiente",
        StateDone = "Hecha",
        SubtasksChip = (done, total) => $"{done}/{total} subtareas",
        RepeatNo = "No",
        RepeatDaily = "Cada día",
        AlertLine = "30 min antes y al vencer",
        AlertLineNoDate = "Sin fecha, sin alerta",
        SectionSubtasks = "SUBTAREAS",
        SectionNotes = "NOTAS",
        CreatedToday = "Creada hoy",
        CreatedOn = date =>
            $"Creada {ShortWeekdays[(int)date.DayOfWeek]} {date.Day} {ShortMonths[date.Month - 1]} · {Texts.Clock(date)}",

        SubtaskPlaceholder = "Añadir subtarea y Enter",
        NewSubtask = "Nueva subtarea",

        NotePlaceholder = "Contexto, links, lo que falta",
        NoteSaveFailed = "No se pudo guardar la nota.",

        DueOverdue = "Vencida",
        DueInMinutes = minutes => $"En {minutes} min",
        DueInHours = (hours, minutes) => $"En {hours} h {minutes} min",
        DueToday = due => $"Hoy {Texts.Clock(due)}",
        DueOtherDay = due => $"{ShortWeekdays[(int)due.DayOfWeek]} {Texts.Clock(due)}",

        SinceYesterday = "De ayer",
        SinceDay = entered => $"Desde {ShortWeekdays[(int)entered.DayOfWeek]} {entered.Day}",

        AlertOverdueTitle = "Prioridad vencida",
        AlertDuePrefix = "Vence ",
        AlertTestBody = "Revisa tu lista de hoy",
        AlertOpen = "Abrir",
        AlertSnooze = "Posponer 15 min",
        TestAlert = "Probar alerta",
        AlertsOff = "Las alertas están desactivadas.",
        OpenSettings = "Abrir ajustes",

        NotesToday = "Notas de hoy",
        NotesWeek = "Notas de la semana",
        NotesPlaceholder = "Escribe una nota",
        NotesSavedHint = "Se guarda al escribir.",

        CaptureTitle = "Nueva prioridad",
        CaptureHint = "Enter agrega. Escape cierra.",
        CaptureSaveFailed = "No se pudo guardar la prioridad.",

        SettingsTitle = "Ajustes",
        SettingsClose = "Cerrar ajustes",
        StateOn = "Activado",
        StateOff = "Desactivado",
        LoginTitle = "Abrir al iniciar sesión",
        LoginDetail = "Abre Daily ZGT cuando inicias sesión en tu computadora.",
        LoginApproval = "Falta tu aprobación en Configuración.",
        LoginFailed = "Windows no aceptó el cambio.",
        TodayLimitTitle = "Máximo 5 prioridades abiertas en Hoy",
        TodayLimitDetail = "Con 5 abiertas en Hoy, no puedes añadir ni mover otra a Hoy.",
        NextPriorityTitle = "Siguiente prioridad en la barra de tareas",
        NextPriorityDetail = "Muestra al pasar sobre el ícono el título de la primera prioridad abierta de Hoy.",
        ShortcutTitle = "Atajo global",
        ShortcutDetail = "Abre la ventana de captura desde cualquier app.",
        ShortcutClearedDetail = "Sin atajo: la ventana de captura no se abre desde otras apps.",
        ShortcutEmpty = "Sin atajo",
        ShortcutRecording = "Pulsa un atajo",
        ShortcutClear = "Borrar atajo",
        ShortcutNeedsModifier = "El atajo necesita Ctrl, Alt, Mayús o Win, o una tecla de función.",
        ShortcutTaken = "El sistema u otra app ya usan esas teclas.",
        KeyCtrl = "Ctrl",
        KeyAlt = "Alt",
        KeyShift = "Mayús",
        KeyWin = "Win",
        KeyBackspace = "Retroceso",
        KeyTab = "Tab",
        KeyEnter = "Entrar",
        KeyPause = "Pausa",
        KeyCapsLock = "Bloq Mayús",
        KeyEscape = "Esc",
        KeySpace = "Espacio",
        KeyPageUp = "Re Pág",
        KeyPageDown = "Av Pág",
        KeyEnd = "Fin",
        KeyHome = "Inicio",
        KeyLeft = "Izquierda",
        KeyUp = "Arriba",
        KeyRight = "Derecha",
        KeyDown = "Abajo",
        KeyPrintScreen = "Impr Pant",
        KeyInsert = "Insertar",
        KeyDelete = "Supr",
        KeyNumpad = digit => $"Num {digit}",
        KeyOther = code => $"Tecla {code:X2}",

        FooterToday = (done, total) => $"{done} de {total} hechas hoy",
        FooterWeek = (done, total) => $"{done} de {total} hechas esta semana",
        Quit = "Salir",
    };
}
