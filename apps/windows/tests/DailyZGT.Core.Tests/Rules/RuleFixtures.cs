using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Tests.Rules;

internal static class Languages
{
    public static readonly Texts Es = Texts.Es;
    public static readonly Texts En = Texts.En;
    public static readonly Texts Pt = Texts.Pt;
}

internal static class RuleFixtures
{
    public static DateTime At(string text) =>
        LocalTime.Parse(text) ?? throw new ArgumentException($"Not a local time: {text}");

    public static Priority MakePriority(
        string id = "p1",
        string? due = null,
        string? done = null,
        string? title = null,
        PriorityList list = PriorityList.Today,
        int position = 1) =>
        new(
            id,
            title ?? $"Title {id}",
            "",
            PriorityLevel.Medium,
            list,
            due is null ? null : At(due),
            done is null ? null : At(done),
            position,
            At("2026-10-12T09:00:00"),
            At("2026-10-12T09:00:00"));
}
