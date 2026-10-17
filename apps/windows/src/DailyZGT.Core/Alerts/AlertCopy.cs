using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;

namespace DailyZGT.Core.Alerts;

public static class AlertCopy
{
    private static readonly TimeSpan OverdueMargin = TimeSpan.FromSeconds(30);

    // The title is computed for the time the alert fires, so a snoozed alert reads `Vence en 14 min`.
    public static string Title(DateTime fireAt, DateTime due, Texts texts)
    {
        if (due - fireAt < OverdueMargin || DueChip.Make(due, fireAt, texts) is not { } chip)
        {
            return texts.AlertOverdueTitle;
        }

        return texts.AlertDueTitle(chip.Label);
    }
}
