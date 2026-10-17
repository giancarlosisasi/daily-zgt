using System.Reflection;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Tests.Localization;

public class TextsTests
{
    public static TheoryData<AppLanguage> Languages => new() { AppLanguage.Es, AppLanguage.En, AppLanguage.Pt };

    [Fact]
    public void No_catalog_has_an_empty_string()
    {
        foreach (var texts in Texts.All)
        {
            foreach (var property in PublicProperties())
            {
                var value = property.GetValue(texts);
                var where = $"{texts.Language}.{property.Name}";

                switch (value)
                {
                    case string text:
                        Assert.False(string.IsNullOrWhiteSpace(text), where);
                        break;
                    case IReadOnlyList<string> names:
                        Assert.All(names, name => Assert.False(string.IsNullOrWhiteSpace(name), where));
                        break;
                    case Delegate function:
                        Assert.False(string.IsNullOrWhiteSpace(Invoke(function)), where);
                        break;
                    case AppLanguage:
                        break;
                    default:
                        Assert.Fail($"{where} has an unexpected type {property.PropertyType}.");
                        break;
                }
            }
        }
    }

    [Fact]
    public void The_catalog_holds_one_instance_per_language()
    {
        Assert.Equal([AppLanguage.Es, AppLanguage.En, AppLanguage.Pt], Texts.All.Select(texts => texts.Language));
        Assert.Same(Texts.Es, Texts.For(AppLanguage.Es));
        Assert.Same(Texts.En, Texts.For(AppLanguage.En));
        Assert.Same(Texts.Pt, Texts.For(AppLanguage.Pt));
    }

    [Theory]
    [MemberData(nameof(Languages))]
    public void The_name_tables_have_the_right_size(AppLanguage language)
    {
        var texts = Texts.For(language);

        Assert.Equal(7, texts.Weekdays.Count);
        Assert.Equal(7, texts.ShortWeekdays.Count);
        Assert.Equal(12, texts.Months.Count);
        Assert.Equal(12, texts.ShortMonths.Count);
        Assert.Equal(texts.Weekdays.Count, texts.Weekdays.Distinct().Count());
        Assert.Equal(texts.ShortMonths.Count, texts.ShortMonths.Distinct().Count());
    }

    [Theory]
    [MemberData(nameof(Languages))]
    public void The_weekday_tables_start_on_sunday(AppLanguage language)
    {
        var texts = Texts.For(language);
        var sunday = new DateTime(2026, 10, 4);

        Assert.Equal(texts.Weekdays[0], texts.Weekday(sunday));
        Assert.Equal(texts.ShortWeekdays[0], texts.ShortWeekday(sunday));
        Assert.Equal(texts.Weekdays[1], texts.Weekday(sunday.AddDays(1)));
        Assert.Equal(texts.ShortMonths[9], texts.ShortMonth(sunday));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Queda 1 subtarea abierta.", "Quedan 3 subtareas abiertas.")]
    [InlineData(AppLanguage.En, "1 subtask is still open.", "3 subtasks are still open.")]
    [InlineData(AppLanguage.Pt, "Resta 1 subtarefa aberta.", "Restam 3 subtarefas abertas.")]
    public void The_open_subtasks_line_has_a_singular_and_a_plural(AppLanguage language, string one, string many)
    {
        var texts = Texts.For(language);

        Assert.Equal(one, texts.SubtasksLeft(1));
        Assert.Equal(many, texts.SubtasksLeft(3));
        Assert.Equal(many.Replace("3", "12"), texts.SubtasksLeft(12));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Hechas (0)", "Hechas (4)", "1 de 5 hechas hoy", "1 de 5 hechas esta semana", "Hecha: Enviar la propuesta")]
    [InlineData(AppLanguage.En, "Completed (0)", "Completed (4)", "1 of 5 done today", "1 of 5 done this week", "Done: Enviar la propuesta")]
    [InlineData(AppLanguage.Pt, "Concluídas (0)", "Concluídas (4)", "1 de 5 concluídas hoje", "1 de 5 concluídas nesta semana", "Concluída: Enviar la propuesta")]
    public void The_counts_and_the_undo_line(
        AppLanguage language,
        string doneZero,
        string doneFour,
        string footerToday,
        string footerWeek,
        string undo)
    {
        var texts = Texts.For(language);

        Assert.Equal(doneZero, texts.DoneHeader(0));
        Assert.Equal(doneFour, texts.DoneHeader(4));
        Assert.Equal(footerToday, texts.FooterToday(1, 5));
        Assert.Equal(footerWeek, texts.FooterWeek(1, 5));
        Assert.Equal(undo, texts.UndoLine("Enviar la propuesta"));
    }

    [Theory]
    [MemberData(nameof(Languages))]
    public void The_composed_labels_use_the_scope_names(AppLanguage language)
    {
        var texts = Texts.For(language);

        Assert.Equal($"{texts.ScopeToday} · 3", texts.TodayTab(3));
        Assert.Equal($"{texts.ScopeWeek} · 0", texts.WeekTab(0));
        Assert.Equal("1/3", texts.SubtaskRatio(1, 3));
        Assert.Equal("Daily ZGT · 7", texts.TrayTooltip(7));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "1/3 subtareas")]
    [InlineData(AppLanguage.En, "1/3 subtasks")]
    [InlineData(AppLanguage.Pt, "1/3 subtarefas")]
    public void The_subtasks_chip(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).SubtasksChip(1, 3));
    }

    [Fact]
    public void Spanish_is_the_text_of_the_product_spec()
    {
        var es = Texts.Es;

        Assert.Equal("Prioridades", es.TabPriorities);
        Assert.Equal("Nada pendiente en esta lista.", es.EmptyNothingPending);
        Assert.Equal("Todo listo en esta lista", es.EmptyAllDone);
        Assert.Equal("¿Qué es prioritario?", es.TitlePlaceholder);
        Assert.Equal("Alerta con sonido 30 min antes y al vencer", es.DueNote);
        Assert.Equal("Hoy ya tiene 5 prioridades abiertas.", es.TodayLimitMessage);
        Assert.Equal("¿Marcar como hecha?", es.ConfirmDoneTitle);
        Assert.Equal("Nada en el historial.", es.HistoryEmpty);
        Assert.Equal("Sin fecha, sin alerta", es.AlertLineNoDate);
        Assert.Equal("30 min antes y al vencer", es.AlertLine);
        Assert.Equal("Añadir subtarea y Enter", es.SubtaskPlaceholder);
        Assert.Equal("Contexto, links, lo que falta", es.NotePlaceholder);
        Assert.Equal("Prioridad vencida", es.AlertOverdueTitle);
        Assert.Equal("Revisa tu lista de hoy", es.AlertTestBody);
        Assert.Equal("Las alertas están desactivadas.", es.AlertsOff);
        Assert.Equal("Enter agrega. Escape cierra.", es.CaptureHint);
        Assert.Equal("No se pudo guardar la prioridad.", es.CaptureSaveFailed);
        Assert.Equal("No se pudo abrir la base de datos.", es.DatabaseOpenFailed);
        Assert.Equal("Se guarda al escribir.", es.NotesSavedHint);
        Assert.Equal("Mayús", es.KeyShift);
    }

    [Fact]
    public void Spanish_settings_use_the_windows_copy()
    {
        var es = Texts.Es;

        Assert.Equal("Abre Daily ZGT cuando inicias sesión en tu computadora.", es.LoginDetail);
        Assert.Equal("Falta tu aprobación en Configuración.", es.LoginApproval);
        Assert.Equal("Windows no aceptó el cambio.", es.LoginFailed);
        Assert.Equal("Siguiente prioridad en la barra de tareas", es.NextPriorityTitle);
        Assert.Equal(
            "Muestra al pasar sobre el ícono el título de la primera prioridad abierta de Hoy.",
            es.NextPriorityDetail);
        Assert.Equal("Máximo 5 prioridades abiertas en Hoy", es.TodayLimitTitle);
        Assert.Equal("Con 5 abiertas en Hoy, no puedes añadir ni mover otra a Hoy.", es.TodayLimitDetail);
        Assert.Equal("Sin atajo: la ventana de captura no se abre desde otras apps.", es.ShortcutClearedDetail);
    }

    [Fact]
    public void English_and_Portuguese_reuse_the_website_wording()
    {
        Assert.Equal("Done", Texts.En.StateDone);
        Assert.Equal("Reopen", Texts.En.Reopen);
        Assert.Equal("Overdue", Texts.En.DueOverdue);
        Assert.Equal("Mark as done?", Texts.En.ConfirmDoneTitle);
        Assert.Equal("Concluída", Texts.Pt.StateDone);
        Assert.Equal("Reabrir", Texts.Pt.Reopen);
        Assert.Equal("Atrasada", Texts.Pt.DueOverdue);
        Assert.Equal("Marcar como concluída?", Texts.Pt.ConfirmDoneTitle);
    }

    [Fact]
    public void The_shift_key_is_Mayus_only_in_Spanish()
    {
        Assert.Equal("Mayús", Texts.Es.KeyShift);
        Assert.Equal("Shift", Texts.En.KeyShift);
        Assert.Equal("Shift", Texts.Pt.KeyShift);
    }

    private static IEnumerable<PropertyInfo> PublicProperties() =>
        typeof(Texts).GetProperties(BindingFlags.Public | BindingFlags.Instance);

    private static string Invoke(Delegate function)
    {
        var arguments = function.GetType().GetMethod("Invoke")!.GetParameters()
            .Select(parameter => SampleArgument(parameter.ParameterType))
            .ToArray();
        return (string)function.DynamicInvoke(arguments)!;
    }

    private static object SampleArgument(Type type) =>
        type == typeof(string) ? "Sample"
        : type == typeof(int) ? 3
        : type == typeof(DateTime) ? new DateTime(2026, 10, 12, 16, 0, 0)
        : throw new NotSupportedException(type.ToString());
}
