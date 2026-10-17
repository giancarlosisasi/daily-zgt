using DailyZGT.Core.Rules;

namespace DailyZGT.Core.Alerts;

public static class AlertCopy
{
    public const string Overdue = "Prioridad vencida";
    public const string TestBody = "Revisa tu lista de hoy";
    public const string Open = "Abrir";
    public const string Snooze = "Posponer 15 min";
    public const string Test = "Probar alerta";
    public const string Off = "Las alertas están desactivadas.";
    public const string OpenSettings = "Abrir ajustes";

    private static readonly TimeSpan OverdueMargin = TimeSpan.FromSeconds(30);

    // The title is computed for the time the alert fires, so a snoozed alert reads `Vence en 14 min`.
    public static string Title(DateTime fireAt, DateTime due)
    {
        if (due - fireAt < OverdueMargin || DueChip.Make(due, fireAt) is not { } chip)
        {
            return Overdue;
        }

        return "Vence " + char.ToLowerInvariant(chip.Label[0]) + chip.Label[1..];
    }
}
