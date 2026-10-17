using System.Runtime.InteropServices;
using DailyZGT.Platform.Native;
using Microsoft.Win32;

namespace DailyZGT.Platform;

public sealed class WindowsTrayIcon : ITrayIcon
{
    private const uint IconId = 1;
    private const int CallbackMessage = 0x8000 + 1;
    private const int OpenCommand = 1;
    private const int QuitCommand = 2;
    private const int MaxTooltipLength = 127;
    private const string TaskbarClass = "Shell_TrayWnd";

    private readonly uint taskbarCreated = Win32.RegisterWindowMessage("TaskbarCreated");
    private HiddenWindow? window;
    private IconHandle? icon;
    private int? count;
    private string tooltip = "Daily ZGT";
    private bool added;
    private bool lastLightTaskbar;
    private int lastPixels;

    public event EventHandler? Clicked;

    public event EventHandler? OpenRequested;

    public event EventHandler? QuitRequested;

    public void Show()
    {
        if (window is not null)
        {
            return;
        }

        window = new HiddenWindow("DailyZGT.Tray", messageOnly: false, OnMessage);
        AllowDarkMenus();
        Add();
    }

    public void Update(int? count, string tooltip)
    {
        this.count = count;
        this.tooltip = tooltip;
        if (window is null)
        {
            return;
        }

        Apply(Win32.NIM_MODIFY);
    }

    public ScreenRect? GetScreenRect()
    {
        if (window is null || !added)
        {
            return null;
        }

        var identifier = new Win32.NotifyIconIdentifier
        {
            cbSize = (uint)Marshal.SizeOf<Win32.NotifyIconIdentifier>(),
            hWnd = window.Handle,
            uID = IconId,
        };
        return Win32.Shell_NotifyIconGetRect(ref identifier, out var rect) == 0
            ? new ScreenRect(rect.Left, rect.Top, rect.Right, rect.Bottom)
            : null;
    }

    public void Dispose()
    {
        if (window is null)
        {
            return;
        }

        if (added)
        {
            var data = NewData(0);
            Win32.ShellNotifyIcon(Win32.NIM_DELETE, ref data);
            added = false;
        }

        icon?.Dispose();
        icon = null;
        window.Dispose();
        window = null;
    }

    private static bool IsLightTaskbar()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("SystemUsesLightTheme") is int value && value != 0;
    }

    private static void AllowDarkMenus()
    {
        try
        {
            Win32.SetPreferredAppMode(1);
            Win32.FlushMenuThemes();
        }
        catch (Exception error) when (error is EntryPointNotFoundException or DllNotFoundException)
        {
        }
    }

    private static int IconPixels(nint hwnd)
    {
        var taskbar = Win32.FindWindow(TaskbarClass, null);
        var dpi = taskbar != 0 ? Win32.GetDpiForWindow(taskbar) : 0;
        if (dpi == 0)
        {
            dpi = hwnd != 0 ? Win32.GetDpiForWindow(hwnd) : Win32.GetDpiForSystem();
        }

        return Math.Max(16, Win32.GetSystemMetricsForDpi(Win32.SM_CXSMICON, dpi == 0 ? 96 : dpi));
    }

    private void Add()
    {
        Apply(Win32.NIM_ADD);
        var data = NewData(0);
        data.uVersion = Win32.NOTIFYICON_VERSION_4;
        Win32.ShellNotifyIcon(Win32.NIM_SETVERSION, ref data);
    }

    private void Apply(uint command)
    {
        lastLightTaskbar = IsLightTaskbar();
        lastPixels = IconPixels(window!.Handle);
        var next = IconHandle.From(TrayIconRenderer.Render(lastPixels, count, lastLightTaskbar));
        var data = NewData(Win32.NIF_MESSAGE | Win32.NIF_ICON | Win32.NIF_TIP | Win32.NIF_SHOWTIP);
        data.hIcon = next.Handle;
        data.szTip = tooltip.Length > MaxTooltipLength ? tooltip[..MaxTooltipLength] : tooltip;
        if (Win32.ShellNotifyIcon(command, ref data))
        {
            added = true;
        }

        icon?.Dispose();
        icon = next;
    }

    private Win32.NotifyIconData NewData(uint flags) => new()
    {
        cbSize = (uint)Marshal.SizeOf<Win32.NotifyIconData>(),
        hWnd = window!.Handle,
        uID = IconId,
        uFlags = flags,
        uCallbackMessage = CallbackMessage,
        szTip = string.Empty,
        szInfo = string.Empty,
        szInfoTitle = string.Empty,
    };

    private void RefreshIfChanged()
    {
        if (window is not null && added && (IsLightTaskbar() != lastLightTaskbar || IconPixels(window.Handle) != lastPixels))
        {
            Apply(Win32.NIM_MODIFY);
        }
    }

    private nint OnMessage(nint hwnd, int message, nint wParam, nint lParam, ref bool handled)
    {
        if (message == CallbackMessage)
        {
            handled = true;
            switch ((int)(lParam & 0xFFFF))
            {
                case Win32.NIN_SELECT or Win32.NIN_KEYSELECT:
                    Clicked?.Invoke(this, EventArgs.Empty);
                    break;
                case Win32.WM_CONTEXTMENU:
                    ShowMenu((short)(wParam & 0xFFFF), (short)((wParam >> 16) & 0xFFFF));
                    break;
            }
        }
        else if (message == taskbarCreated)
        {
            added = false;
            Add();
        }
        else if (message is Win32.WM_SETTINGCHANGE or Win32.WM_DISPLAYCHANGE)
        {
            RefreshIfChanged();
        }

        return 0;
    }

    private void ShowMenu(int x, int y)
    {
        var menu = Win32.CreatePopupMenu();
        try
        {
            Win32.AppendMenu(menu, Win32.MF_STRING, OpenCommand, "Abrir");
            Win32.AppendMenu(menu, Win32.MF_STRING, QuitCommand, "Salir");
            Win32.SetForegroundWindow(window!.Handle);
            var command = Win32.TrackPopupMenuEx(
                menu,
                Win32.TPM_RIGHTBUTTON | Win32.TPM_BOTTOMALIGN | Win32.TPM_RETURNCMD | Win32.TPM_NONOTIFY,
                x,
                y,
                window.Handle,
                0);
            Win32.PostMessage(window.Handle, Win32.WM_NULL, 0, 0);
            switch (command)
            {
                case OpenCommand:
                    OpenRequested?.Invoke(this, EventArgs.Empty);
                    break;
                case QuitCommand:
                    QuitRequested?.Invoke(this, EventArgs.Empty);
                    break;
            }
        }
        finally
        {
            Win32.DestroyMenu(menu);
        }
    }
}
