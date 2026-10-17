using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using DailyZGT.Platform;

namespace DailyZGT.Shell;

// F02. The borderless panel above the tray. Its height follows the content up to the work area, it stays
// anchored to the taskbar edge as it grows, and it hides when the focus goes to another app.
public partial class PanelWindow : Window
{
    private const double Gap = 12;

    // Room for the Tecla panel shadow around the surface. The side that faces the taskbar keeps only the
    // gap, so the window never covers the taskbar and a click on the tray icon still reaches it.
    private static readonly Thickness ShadowRoom = new(28, 20, 28, 50);

    // A click on the tray icon first takes the focus from the panel. A toggle that close behind the hide
    // is that same click, so it must not open the panel again.
    private const long ReopenGuardMs = 400;

    // An alert's Abrir hands the focus over while the toast closes; the panel keeps itself open meanwhile.
    private const long ToastGraceMs = 1500;

    private readonly Func<ScreenRect?> trayIcon;
    private nint handle;
    private TaskbarEdge edge = TaskbarEdge.Bottom;
    private long keepOpenUntil;
    private long hiddenByFocusLossAt = long.MinValue / 2;

    public PanelWindow(FrameworkElement content, Func<ScreenRect?> trayIcon)
    {
        InitializeComponent();
        Surface.Content = content;
        this.trayIcon = trayIcon;
        SourceInitialized += OnSourceInitialized;
        Deactivated += OnDeactivated;
        SizeChanged += (_, _) => Place();
        PreviewMouseDown += OnPreviewMouseDown;
        IsVisibleChanged += OnVisibleChanged;
    }

    public void Toggle()
    {
        if (IsVisible)
        {
            Hide();
        }
        else if (Environment.TickCount64 - hiddenByFocusLossAt > ReopenGuardMs)
        {
            Open(fromToast: false);
        }
    }

    public void Open(bool fromToast)
    {
        if (fromToast)
        {
            keepOpenUntil = Environment.TickCount64 + ToastGraceMs;
        }

        if (!IsVisible)
        {
            Show();
            UpdateLayout();
            Place();
            ShellMotion.Pop(Surface, edge == TaskbarEdge.Top ? -1 : 1, PopOrigin(edge));
        }

        Activate();
    }

    private static Point PopOrigin(TaskbarEdge edge) => edge switch
    {
        TaskbarEdge.Top => new Point(1, 0),
        TaskbarEdge.Left => new Point(0, 1),
        _ => new Point(1, 1),
    };

    private static int Pixels(double value, double scale) => (int)Math.Round(value * scale);

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        handle = new WindowInteropHelper(this).Handle;
        Desktop.HideFromTaskSwitcher(handle);
    }

    private void Place()
    {
        if (!IsVisible || handle == 0)
        {
            return;
        }

        var scale = Desktop.Scale(handle);
        var icon = trayIcon();
        var taskbar = Desktop.Taskbar();
        var work = icon is { } shown ? Desktop.WorkAreaNear(shown)
            : taskbar is { } bar ? Desktop.WorkAreaNear(bar.Bounds)
            : Desktop.WorkAreaAtCursor();
        edge = taskbar?.Edge ?? TaskbarEdge.Bottom;
        Surface.Margin = new Thickness(
            edge == TaskbarEdge.Left ? Gap : ShadowRoom.Left,
            edge == TaskbarEdge.Top ? Gap : ShadowRoom.Top,
            edge == TaskbarEdge.Right ? Gap : ShadowRoom.Right,
            edge == TaskbarEdge.Bottom ? Gap : ShadowRoom.Bottom);
        var gap = Pixels(Gap, scale);
        Surface.MaxHeight = PanelPlacement.MaxHeight(work, gap) / scale;
        var size = new ScreenSize(Pixels(Surface.ActualWidth, scale), Pixels(Surface.ActualHeight, scale));
        var at = PanelPlacement.TopLeft(size, work, edge, taskbar?.Bounds, icon, gap);
        Desktop.MoveTo(handle, at.X - Pixels(Surface.Margin.Left, scale), at.Y - Pixels(Surface.Margin.Top, scale));
    }

    // The shadow around the surface is part of the window. A click there is a click outside the panel.
    private void OnPreviewMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is Visual target && target != Surface && !Surface.IsAncestorOf(target))
        {
            e.Handled = true;
            HideAfterFocusLoss();
        }
    }

    // A focus ring left from the last open would be drawn where the pop animation started, off its control.
    private void OnVisibleChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (!IsVisible)
        {
            FocusManager.SetFocusedElement(this, null);
        }
    }

    private void HideAfterFocusLoss()
    {
        hiddenByFocusLossAt = Environment.TickCount64;
        Hide();
    }

    // The check waits for the activation to settle, so the foreground window is the one that took the focus.
    private void OnDeactivated(object? sender, EventArgs e) =>
        Dispatcher.BeginInvoke(DispatcherPriority.Background, () =>
        {
            if (!IsVisible || IsActive || Desktop.ForegroundIsOwnedBy(handle))
            {
                return;
            }

            if (Environment.TickCount64 < keepOpenUntil)
            {
                Activate();
                return;
            }

            HideAfterFocusLoss();
        });
}
