using System.Runtime.InteropServices;
using DailyZGT.Shell;

namespace DailyZGT.Platform;

// The parts of the Windows desktop the panel and the capture window place themselves against, in screen
// pixels, and the foreground window they hand the focus back to.
public static class Desktop
{
    private const uint AbmGetTaskbarPos = 5;
    private const uint MonitorDefaultToNearest = 2;
    private const uint GwOwner = 4;
    private const int GwlExStyle = -20;
    private const nint WsExToolWindow = 0x80;
    private const nint WsExAppWindow = 0x40000;
    private const uint SwpNoSize = 0x1;
    private const uint SwpNoZOrder = 0x4;
    private const uint SwpNoActivate = 0x10;
    private const uint AsfwAny = uint.MaxValue;

    public static (TaskbarEdge Edge, ScreenRect Bounds)? Taskbar()
    {
        var data = new AppBarData { cbSize = (uint)Marshal.SizeOf<AppBarData>() };
        if (SHAppBarMessage(AbmGetTaskbarPos, ref data) == 0)
        {
            return null;
        }

        var edge = data.uEdge switch
        {
            0 => TaskbarEdge.Left,
            1 => TaskbarEdge.Top,
            2 => TaskbarEdge.Right,
            _ => TaskbarEdge.Bottom,
        };
        return (edge, ToScreen(data.rc));
    }

    public static ScreenRect WorkAreaNear(ScreenRect rect)
    {
        var native = new Native.Win32.Rect { Left = rect.Left, Top = rect.Top, Right = rect.Right, Bottom = rect.Bottom };
        return WorkArea(MonitorFromRect(ref native, MonitorDefaultToNearest));
    }

    public static ScreenRect WorkAreaAtCursor()
    {
        GetCursorPos(out var point);
        return WorkArea(MonitorFromPoint(point, MonitorDefaultToNearest));
    }

    // The window that has the focus now, or 0 when it belongs to this process.
    public static nint ForeignForegroundWindow()
    {
        var window = GetForegroundWindow();
        return window != 0 && !IsOwnWindow(window) ? window : 0;
    }

    // True when the focus went to a window the given one owns, such as a picker it opened.
    public static bool ForegroundIsOwnedBy(nint owner)
    {
        for (var window = GetForegroundWindow(); window != 0; window = GetWindow(window, GwOwner))
        {
            if (window == owner)
            {
                return true;
            }
        }

        return false;
    }

    // Lets a borderless window stay out of the taskbar and the Alt+Tab list.
    public static void HideFromTaskSwitcher(nint window)
    {
        var style = GetWindowLongPtr(window, GwlExStyle);
        SetWindowLongPtr(window, GwlExStyle, (style | WsExToolWindow) & ~WsExAppWindow);
    }

    // A second launch calls this before it hands its arguments over, so the first instance may take the focus.
    public static void LetAnyProcessTakeFocus() => AllowSetForegroundWindow(AsfwAny);

    public static void MoveTo(nint window, int x, int y) =>
        SetWindowPos(window, 0, x, y, 0, 0, SwpNoSize | SwpNoZOrder | SwpNoActivate);

    public static void Focus(nint window)
    {
        if (window != 0 && IsWindow(window))
        {
            Native.Win32.SetForegroundWindow(window);
        }
    }

    public static double Scale(nint window)
    {
        var dpi = window != 0 ? Native.Win32.GetDpiForWindow(window) : 0;
        return (dpi == 0 ? Native.Win32.GetDpiForSystem() : dpi) / 96.0;
    }

    private static bool IsOwnWindow(nint window)
    {
        GetWindowThreadProcessId(window, out var process);
        return process == (uint)Environment.ProcessId;
    }

    private static ScreenRect WorkArea(nint monitor)
    {
        var info = new MonitorInfo { cbSize = (uint)Marshal.SizeOf<MonitorInfo>() };
        return GetMonitorInfo(monitor, ref info) ? ToScreen(info.rcWork) : ToScreen(default);
    }

    private static ScreenRect ToScreen(Native.Win32.Rect rect) => new(rect.Left, rect.Top, rect.Right, rect.Bottom);

    [StructLayout(LayoutKind.Sequential)]
    private struct AppBarData
    {
        public uint cbSize;
        public nint hWnd;
        public uint uCallbackMessage;
        public uint uEdge;
        public Native.Win32.Rect rc;
        public nint lParam;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo
    {
        public uint cbSize;
        public Native.Win32.Rect rcMonitor;
        public Native.Win32.Rect rcWork;
        public uint dwFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint
    {
        public int X;
        public int Y;
    }

    [DllImport("shell32.dll")]
    private static extern nuint SHAppBarMessage(uint message, ref AppBarData data);

    [DllImport("user32.dll")]
    private static extern nint MonitorFromRect(ref Native.Win32.Rect rect, uint flags);

    [DllImport("user32.dll")]
    private static extern nint MonitorFromPoint(NativePoint point, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(nint monitor, ref MonitorInfo info);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetCursorPos(out NativePoint point);

    [DllImport("user32.dll")]
    private static extern nint GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(nint window, out uint process);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(nint window);

    [DllImport("user32.dll")]
    private static extern nint GetWindow(nint window, uint command);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AllowSetForegroundWindow(uint process);

    [DllImport("user32.dll")]
    private static extern nint GetWindowLongPtr(nint window, int index);

    [DllImport("user32.dll")]
    private static extern nint SetWindowLongPtr(nint window, int index, nint value);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(nint window, nint after, int x, int y, int width, int height, uint flags);
}
