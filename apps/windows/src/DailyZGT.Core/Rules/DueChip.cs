namespace DailyZGT.Core.Rules;

public enum DueTone { Overdue, Soon, Later }

// F12. The label of the due chip and its tone.
public sealed record DueChip(string Label, DueTone Tone)
{
    public static DueChip? Make(DateTime? due, DateTime now)
    {
        if (due is not { } dueAt)
        {
            return null;
        }

        var minutes = (int)Math.Floor((dueAt - now).TotalSeconds / 60 + 0.5);
        if (minutes < 0)
        {
            return new DueChip("Vencida", DueTone.Overdue);
        }

        if (minutes < 120)
        {
            var label = minutes < 60 ? $"En {minutes} min" : $"En {minutes / 60} h {minutes % 60} min";
            return new DueChip(label, DueTone.Soon);
        }

        var time = SpanishNames.Clock(dueAt);
        return dueAt.Date == now.Date
            ? new DueChip($"Hoy {time}", DueTone.Later)
            : new DueChip($"{SpanishNames.ShortWeekday(dueAt)} {time}", DueTone.Later);
    }
}

// F13. Formats the day a priority entered Hoy. The caller finds that day from the event log.
public static class TodayEntryChip
{
    public static DueChip? Make(DateTime? enteredAt, DateTime now)
    {
        if (enteredAt is not { } entered)
        {
            return null;
        }

        var days = (now.Date - entered.Date).Days;
        return days switch
        {
            < 1 => null,
            1 => new DueChip("De ayer", DueTone.Later),
            _ => new DueChip($"Desde {SpanishNames.ShortWeekday(entered)} {entered.Day}", DueTone.Later),
        };
    }
}
