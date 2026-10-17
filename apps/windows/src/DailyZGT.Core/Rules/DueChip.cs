using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Rules;

public enum DueTone { Overdue, Soon, Later }

// F12. The label of the due chip and its tone.
public sealed record DueChip(string Label, DueTone Tone)
{
    public static DueChip? Make(DateTime? due, DateTime now, Texts texts)
    {
        if (due is not { } dueAt)
        {
            return null;
        }

        var minutes = (int)Math.Floor((dueAt - now).TotalSeconds / 60 + 0.5);
        if (minutes < 0)
        {
            return new DueChip(texts.DueOverdue, DueTone.Overdue);
        }

        if (minutes < 120)
        {
            var label = minutes < 60 ? texts.DueInMinutes(minutes) : texts.DueInHours(minutes / 60, minutes % 60);
            return new DueChip(label, DueTone.Soon);
        }

        return dueAt.Date == now.Date
            ? new DueChip(texts.DueToday(dueAt), DueTone.Later)
            : new DueChip(texts.DueOtherDay(dueAt), DueTone.Later);
    }
}

// F13. Formats the day a priority entered Hoy. The caller finds that day from the event log.
public static class TodayEntryChip
{
    public static DueChip? Make(DateTime? enteredAt, DateTime now, Texts texts)
    {
        if (enteredAt is not { } entered)
        {
            return null;
        }

        var days = (now.Date - entered.Date).Days;
        return days switch
        {
            < 1 => null,
            1 => new DueChip(texts.SinceYesterday, DueTone.Later),
            _ => new DueChip(texts.SinceDay(entered), DueTone.Later),
        };
    }
}
