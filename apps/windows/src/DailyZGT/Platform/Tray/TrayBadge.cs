namespace DailyZGT.Platform;

public static class TrayBadge
{
    public const int MaxCount = 9;

    public static string? Text(int? count) => count switch
    {
        null => null,
        > MaxCount => $"{MaxCount}+",
        < 0 => "0",
        _ => count.Value.ToString(System.Globalization.CultureInfo.InvariantCulture),
    };
}
