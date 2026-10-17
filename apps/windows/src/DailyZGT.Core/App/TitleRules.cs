namespace DailyZGT.Core.App;

// F09. A blank title or the same title saves nothing. The title is trimmed.
public static class TitleEdit
{
    public static string? TitleToSave(string draft, string current)
    {
        var trimmed = draft.Trim();
        return trimmed.Length == 0 || trimmed == current ? null : trimmed;
    }
}

// F04. A click on the title opens the detail view. A drag, a pointer that moved more than 3 points, or a
// selection does not, so the title can be copied.
public static class TitleClickRule
{
    public const double MovementTolerance = 3;

    public static bool ShouldOpen((double X, double Y) down, (double X, double Y) up, int selectionLength) =>
        selectionLength == 0
        && Math.Abs(up.X - down.X) <= MovementTolerance
        && Math.Abs(up.Y - down.Y) <= MovementTolerance;
}
