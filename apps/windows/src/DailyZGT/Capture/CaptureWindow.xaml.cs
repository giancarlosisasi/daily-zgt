using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using DailyZGT.Core.App;
using DailyZGT.Platform;
using DailyZGT.Shell;

namespace DailyZGT.Capture;

// F17. The floating window that adds a priority to Hoy. It opens near the top of the screen with the
// pointer, over other windows, and closes as CaptureModel says: Enter, Escape and the shortcut give the
// focus back to the app the person was in, a click elsewhere does not.
public partial class CaptureWindow : Window
{
    private const double TopInset = 80;

    private readonly CaptureModel model;
    private nint handle;
    private nint previous;
    private int showCount;

    public CaptureWindow(CaptureModel model)
    {
        InitializeComponent();
        this.model = model;
        DataContext = model;
        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            Desktop.HideFromTaskSwitcher(handle);
        };
        Deactivated += (_, _) => model.Dismiss();
        model.Opened += (_, _) => Reveal();
        model.Closed += (_, reason) => Conceal(reason);
        model.PropertyChanged += OnModelChanged;
        RenderNotice();
    }

    private void Reveal()
    {
        showCount++;
        previous = Desktop.ForeignForegroundWindow();
        Show();
        UpdateLayout();
        Place();
        Activate();
        Field.Focus();
        ShellMotion.Pop(Surface, -1, new Point(0.5, 0));
    }

    private void Conceal(CaptureCloseReason reason)
    {
        if (reason.RestoresFocus())
        {
            Desktop.Focus(previous);
        }

        previous = 0;
        var closing = showCount;
        ShellMotion.Unpop(Surface, -1, new Point(0.5, 0), () =>
        {
            if (closing == showCount)
            {
                Hide();
            }
        });
    }

    private void Place()
    {
        var scale = Desktop.Scale(handle);
        var size = new ScreenSize((int)Math.Round(Surface.ActualWidth * scale), (int)Math.Round(Surface.ActualHeight * scale));
        var at = CapturePlacement.TopLeft(size, Desktop.WorkAreaAtCursor(), (int)Math.Round(TopInset * scale));
        Desktop.MoveTo(handle, at.X - (int)Math.Round(Surface.Margin.Left * scale), at.Y - (int)Math.Round(Surface.Margin.Top * scale));
    }

    private void OnModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(CaptureModel.Notice))
        {
            RenderNotice();
        }
    }

    private void RenderNotice()
    {
        Notice.Text = model.Notice switch
        {
            CaptureNotice.TodayLimit => UiText.Current.TodayLimitMessage,
            CaptureNotice.SaveFailed => UiText.Current.CaptureSaveFailed,
            _ => "",
        };
        Notice.Visibility = model.Notice == CaptureNotice.None ? Visibility.Collapsed : Visibility.Visible;
    }

    private void OnFieldKey(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Enter:
                e.Handled = true;
                model.Submit();
                break;
            case Key.Escape:
                e.Handled = true;
                model.Cancel();
                break;
        }
    }
}
