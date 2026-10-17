using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Tests.Support;

// A wall clock the test can set to any time, also backwards. The zone is UTC, so the local wall-clock
// time is exactly the text the test writes.
public sealed class TestClock(string start = "2026-10-12T09:00:00") : TimeProvider
{
    public DateTime Now { get; set; } = Time.At(start);

    public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;

    public override DateTimeOffset GetUtcNow() => new(DateTime.SpecifyKind(Now, DateTimeKind.Unspecified), TimeSpan.Zero);

    public void Set(string text) => Now = Time.At(text);

    public void Advance(int minutes) => Now = Now.AddMinutes(minutes);
}

public static class Time
{
    public static DateTime At(string text) =>
        LocalTime.Parse(text) ?? throw new ArgumentException($"Not a local time: {text}", nameof(text));
}
