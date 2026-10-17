using DailyZGT.Platform;
using DailyZGT.Shell;

namespace DailyZGT.Capture;

// F17. The capture window opens centered near the top of the work area of the screen with the pointer.
public static class CapturePlacement
{
    public static ScreenPoint TopLeft(ScreenSize window, ScreenRect workArea, int topInset)
    {
        var x = Math.Max(workArea.Left, Math.Min(workArea.Left + (workArea.Width - window.Width) / 2, workArea.Right - window.Width));
        var y = Math.Max(workArea.Top, Math.Min(workArea.Top + topInset, workArea.Bottom - window.Height));
        return new(x, y);
    }
}
