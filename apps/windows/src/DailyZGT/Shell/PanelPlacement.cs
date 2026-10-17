using DailyZGT.Platform;

namespace DailyZGT.Shell;

public enum TaskbarEdge { Left, Top, Right, Bottom }

public readonly record struct ScreenPoint(int X, int Y);

public readonly record struct ScreenSize(int Width, int Height);

// F02. Where the visible panel goes, in screen pixels. It sits against the taskbar edge of the work area,
// centered on the tray icon when the icon shows on the taskbar, or in the corner by the tray when the
// icon is hidden in the overflow flyout or Windows does not report it.
public static class PanelPlacement
{
    public static ScreenPoint TopLeft(
        ScreenSize panel,
        ScreenRect workArea,
        TaskbarEdge edge,
        ScreenRect? taskbar,
        ScreenRect? icon,
        int gap)
    {
        var anchor = icon is { } shown && taskbar is { } bar && Intersects(shown, bar) ? shown : (ScreenRect?)null;
        var minX = workArea.Left + gap;
        var maxX = workArea.Right - gap - panel.Width;
        var minY = workArea.Top + gap;
        var maxY = workArea.Bottom - gap - panel.Height;
        return edge switch
        {
            TaskbarEdge.Left or TaskbarEdge.Right => new(
                edge == TaskbarEdge.Left ? minX : maxX,
                anchor is { } a ? Clamp(Center(a.Top, a.Bottom) - panel.Height / 2, minY, maxY) : maxY),
            _ => new(
                anchor is { } a ? Clamp(Center(a.Left, a.Right) - panel.Width / 2, minX, maxX) : maxX,
                edge == TaskbarEdge.Top ? minY : maxY),
        };
    }

    // The tallest the panel may grow: the work area less a gap at each end.
    public static int MaxHeight(ScreenRect workArea, int gap) => Math.Max(0, workArea.Height - gap * 2);

    private static int Center(int start, int end) => (start + end) / 2;

    private static int Clamp(int value, int min, int max) => max < min ? min : Math.Clamp(value, min, max);

    private static bool Intersects(ScreenRect a, ScreenRect b) =>
        a.Left < b.Right && b.Left < a.Right && a.Top < b.Bottom && b.Top < a.Bottom;
}
