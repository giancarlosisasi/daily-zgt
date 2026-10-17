namespace DailyZGT.Core.Localization;

// Brazilian Portuguese. Wording from apps/website/i18n.json (`demo.*`) first, then the same voice.
internal static class PortugueseTexts
{
    private static readonly string[] Weekdays =
        ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"];

    private static readonly string[] ShortWeekdays = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"];

    private static readonly string[] Months =
        ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

    private static readonly string[] ShortMonths =
        ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];

    public static Texts Create() => new()
    {
        Language = AppLanguage.Pt,

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
        TrayMenuQuit = "Sair",

        TabPriorities = "Prioridades",
        TabNotes = "Notas",
        ScopeToday = "Hoje",
        ScopeWeek = "Semana",
        DatabaseOpenFailed = "Não foi possível abrir o banco de dados.",
        BackTo = list => $"Voltar para {list}",

        EmptyAllDone = "Tudo pronto nesta lista",
        EmptyNothingPending = "Nada pendente nesta lista.",

        ShowSubtasks = "Mostrar subtarefas",
        HideSubtasks = "Ocultar subtarefas",
        SubtasksLabel = "Subtarefas",
        StateExpanded = "expandido",
        StateCollapsed = "recolhido",
        HasNote = "Tem notas",
        RemoveRow = "Remover",
        MarkDoneCheckbox = title => $"Marcar como concluída: {title}",
        ListSaveFailed = "Não foi possível salvar a alteração.",

        NewPriority = "Nova prioridade",
        TitlePlaceholder = "Qual é a prioridade?",
        LabelPriority = "Prioridade",
        LabelDue = "Prazo",
        LabelList = "Lista",
        LabelRepeat = "Repetir",
        LabelAlert = "Alerta",
        LevelHigh = "Alta",
        LevelMedium = "Média",
        LevelLow = "Baixa",
        LevelHighName = "Prioridade alta",
        LevelMediumName = "Prioridade média",
        LevelLowName = "Prioridade baixa",
        NoDate = "Sem prazo",
        ClearDate = "Remover prazo",
        DueNote = "Alerta com som 30 min antes e no prazo",
        Add = "Adicionar",
        Cancel = "Cancelar",
        PickerPreviousMonth = "Mês anterior",
        PickerNextMonth = "Próximo mês",
        PickerHour = "Hora",
        PickerMinute = "Minuto",
        PickerDone = "Pronto",

        TodayLimitMessage = "Hoje já tem 5 prioridades abertas.",

        ConfirmDoneTitle = "Marcar como concluída?",
        ConfirmDone = "Concluída",
        ConfirmName = "Confirmar",
        MarkDoneButton = "Marcar como concluída",
        Undo = "Desfazer",
        UndoLine = title => $"Concluída: {title}",
        SubtasksLeft = count => count == 1 ? "Resta 1 subtarefa aberta." : $"Restam {count} subtarefas abertas.",

        DoneHeader = count => $"Concluídas ({count})",
        DoneMark = "Concluída",
        Reopen = "Reabrir",
        HistoryTitle = "Histórico",
        HistoryBack = "Voltar para Concluídas",
        HistoryEmpty = "Nada no histórico.",
        Yesterday = "Ontem",

        DetailDelete = "Excluir prioridade",
        TitleField = "Título",
        StateOpen = "Pendente",
        StateDone = "Concluída",
        SubtasksChip = (done, total) => $"{done}/{total} subtarefas",
        RepeatNo = "Não",
        RepeatDaily = "Todo dia",
        AlertLine = "30 min antes e no prazo",
        AlertLineNoDate = "Sem prazo, sem alerta",
        SectionSubtasks = "SUBTAREFAS",
        SectionNotes = "NOTAS",
        CreatedToday = "Criada hoje",
        CreatedOn = date =>
            $"Criada {ShortWeekdays[(int)date.DayOfWeek]} {date.Day} {ShortMonths[date.Month - 1]} · {Texts.Clock(date)}",

        SubtaskPlaceholder = "Adicionar subtarefa e Enter",
        NewSubtask = "Nova subtarefa",

        NotePlaceholder = "Contexto, links, o que falta",
        NoteSaveFailed = "Não foi possível salvar a nota.",

        DueOverdue = "Atrasada",
        DueInMinutes = minutes => $"Em {minutes} min",
        DueInHours = (hours, minutes) => $"Em {hours} h {minutes} min",
        DueToday = due => $"Hoje {Texts.Clock(due)}",
        DueOtherDay = due => $"{ShortWeekdays[(int)due.DayOfWeek]} {Texts.Clock(due)}",

        SinceYesterday = "De ontem",
        SinceDay = entered => $"Desde {ShortWeekdays[(int)entered.DayOfWeek]} {entered.Day}",

        AlertBeforeTitle = "Vence em 30 min",
        AlertOverdueTitle = "Prioridade atrasada",
        AlertDuePrefix = "Vence ",
        AlertTestBody = "Confira sua lista de hoje",
        AlertOpen = "Abrir",
        AlertSnooze = "Adiar 15 min",
        TestAlert = "Testar alerta",
        AlertsOff = "Os alertas estão desativados.",
        OpenSettings = "Abrir ajustes",

        NotesToday = "Notas de hoje",
        NotesWeek = "Notas da semana",
        NotesPlaceholder = "Escreva uma nota",
        NotesSavedHint = "Salva ao digitar.",

        CaptureTitle = "Nova prioridade",
        CaptureHint = "Enter adiciona. Escape fecha.",
        CaptureSaveFailed = "Não foi possível salvar a prioridade.",

        SettingsTitle = "Ajustes",
        SettingsClose = "Fechar ajustes",
        StateOn = "Ativado",
        StateOff = "Desativado",
        LoginTitle = "Abrir ao fazer login",
        LoginDetail = "Abre o Daily ZGT quando você faz login no computador.",
        LoginApproval = "Falta sua aprovação em Configurações.",
        LoginFailed = "O Windows não aceitou a alteração.",
        TodayLimitTitle = "Máximo de 5 prioridades abertas em Hoje",
        TodayLimitDetail = "Com 5 abertas em Hoje, você não pode adicionar nem mover outra para Hoje.",
        NextPriorityTitle = "Próxima prioridade na barra de tarefas",
        NextPriorityDetail = "Mostra o título da primeira prioridade aberta de Hoje ao passar o mouse sobre o ícone.",
        ShortcutTitle = "Atalho global",
        ShortcutDetail = "Abre a janela de captura de qualquer app.",
        ShortcutClearedDetail = "Sem atalho: a janela de captura não abre a partir de outros apps.",
        ShortcutEmpty = "Sem atalho",
        ShortcutRecording = "Pressione um atalho",
        ShortcutClear = "Limpar atalho",
        ShortcutNeedsModifier = "O atalho precisa de Ctrl, Alt, Shift ou Win, ou de uma tecla de função.",
        ShortcutTaken = "O sistema ou outro app já usa essas teclas.",
        KeyCtrl = "Ctrl",
        KeyAlt = "Alt",
        KeyShift = "Shift",
        KeyWin = "Win",

        FooterToday = (done, total) => $"{done} de {total} concluídas hoje",
        FooterWeek = (done, total) => $"{done} de {total} concluídas nesta semana",
        Quit = "Sair",
    };
}
