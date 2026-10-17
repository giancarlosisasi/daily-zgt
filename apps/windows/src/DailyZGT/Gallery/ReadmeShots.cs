using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Rectangle = System.Windows.Shapes.Rectangle;
using System.Windows.Threading;
using DailyZGT.Capture;
using DailyZGT.Core.Alerts;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Platform;
using DailyZGT.Shell;
using DailyZGT.Theme;

namespace DailyZGT.Gallery;

internal sealed class NoAlerts : IAlertSystem
{
    public AlertAuthorization Authorization => AlertAuthorization.Authorized;

    public event EventHandler<AlertResponse>? Responded
    {
        add { }
        remove { }
    }

    public void Start()
    {
    }

    public IReadOnlyList<AlertRequest> Pending() => [];

    public IReadOnlyList<string> DeliveredIds() => [];

    public void Schedule(AlertRequest request)
    {
    }

    public void RemovePending(IEnumerable<string> ids)
    {
    }

    public void RemoveDelivered(IEnumerable<string> ids)
    {
    }
}

// The images of the README and of the website docs. Each one is drawn from a visual tree that no window
// shows, on a PanelState over the demo store in the current language, and rendered to a bitmap at 2x.
// Nothing reads the screen. Every shot opens its own store, so the order of a set changes no image.
internal static class ReadmeShots
{
    private const double Scale = 2;
    private const double Margin = 24;

    public static readonly IReadOnlyList<string> Readme = ["priorities", "detail", "notes", "settings", "capture", "tray"];

    public static readonly IReadOnlyList<string> Docs =
    [
        "tray", "priorities", "week", "new-priority", "confirm", "undo", "completed", "detail", "notes", "capture", "settings",
    ];

    private static readonly IReadOnlyDictionary<string, Action<string>> Shots = new Dictionary<string, Action<string>>
    {
        ["tray"] = Tray,
        ["priorities"] = path => Panel(path, _ => { }),
        ["week"] = path => Panel(path, scene => scene.Data.Panel.SelectScope(PriorityList.Week)),
        ["new-priority"] = path => Panel(path, scene =>
        {
            var form = scene.Data.Panel.Form;
            form.Open();
            form.Title = DemoWords.For(UiText.Current.Language).NewTitle;
            form.Level = PriorityLevel.High;
            form.PickDefaultDue();
        }),
        ["confirm"] = path => Panel(path, scene => scene.Data.Panel.Flow.ToggleConfirmation(scene.Data.ProposalId)),
        ["undo"] = path => Panel(path, scene => scene.Data.Panel.Flow.ConfirmDone(scene.Data.ProposalId, DoneOrigin.List)),
        ["completed"] = path => Panel(path, scene => scene.Data.Panel.ToggleDone()),
        ["detail"] = path => Panel(path, scene => scene.Data.Panel.OpenDetail(scene.Data.ProposalId)),
        ["notes"] = path => Panel(path, scene => scene.Data.Panel.SelectTab(PanelTab.Notes)),
        ["settings"] = path => Panel(path, scene => scene.Data.Panel.ToggleSettings()),
        ["capture"] = Capture,
    };

    public static void Run(string folder, IReadOnlyList<string> names)
    {
        Motion.IsReduced = true;
        Directory.CreateDirectory(folder);
        foreach (var name in names)
        {
            Shots[name](Path.Combine(folder, $"{name}.png"));
        }
    }

    private sealed class Scene(PreviewData data, ShellModel shell) : IDisposable
    {
        public PreviewData Data { get; } = data;

        public ShellModel Shell { get; } = shell;

        public static Scene Open()
        {
            var data = new PreviewData(SynchronizationContext.Current, readme: true);
            var alerts = new AlertCoordinator(data.Store, new NoAlerts(), UiText.Current, data.Time);
            var shell = new ShellModel(data.Panel, data.Store, data.Clock, alerts, new TraySummary(data.Store), UiText.Current);
            return new Scene(data, shell);
        }

        public void Dispose()
        {
            Shell.Dispose();
            Data.Dispose();
        }
    }

    private static void Panel(string path, Action<Scene> arrange)
    {
        using var scene = Scene.Open();
        var view = new PanelShellView();
        view.Attach(scene.Shell);
        arrange(scene);
        Save(new ContentControl { Style = Style("Tecla.Panel"), Content = view }, path);
    }

    private static void Capture(string path)
    {
        using var data = new PreviewData(SynchronizationContext.Current, readme: true);
        var model = new CaptureModel(data.Store) { Title = DemoWords.For(UiText.Current.Language).CaptureTitle };
        var window = new CaptureWindow(model);
        var surface = (ContentControl)window.Content;
        window.Content = null;
        surface.DataContext = model;
        surface.Margin = new Thickness(0);
        window.Field.ApplyTemplate();
        ((UIElement)window.Field.Template.FindName("Ring", window.Field)).Visibility = Visibility.Visible;
        Save(surface, path);
    }

    // The icon as the tray draws it, on a taskbar chip, under the tooltip text in the Tecla tooltip.
    private static void Tray(string path)
    {
        using var scene = Scene.Open();
        var icon = TrayIconRenderer.Render(64, scene.Shell.Tray.Count, lightTaskbar: false);
        var tooltip = new ToolTip { Content = new TextBlock { Text = scene.Shell.TrayTooltip } };
        tooltip.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        tooltip.Arrange(new Rect(tooltip.DesiredSize));
        var tooltipImage = new Rectangle
        {
            Width = tooltip.DesiredSize.Width,
            Height = tooltip.DesiredSize.Height,
            HorizontalAlignment = HorizontalAlignment.Left,
            Fill = new VisualBrush(tooltip),
        };
        var taskbar = new Border
        {
            Background = (Brush)Application.Current.FindResource("Brush.Panel.Card"),
            BorderBrush = (Brush)Application.Current.FindResource("Brush.Panel.Line"),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12),
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 8, 0, 0),
            Child = new Image { Source = icon, Width = 32, Height = 32, SnapsToDevicePixels = true },
        };
        var stack = new StackPanel { Margin = new Thickness(16, 8, 16, 8), Children = { tooltipImage, taskbar } };
        Save(stack, path);
    }

    private static Style Style(string key) => (Style)Application.Current.FindResource(key);

    // A window far outside every screen gives the views their Loaded pass. The bitmap comes from the visual
    // tree, never from the screen.
    private static void Save(FrameworkElement content, string path)
    {
        var stage = new Border
        {
            Background = (Brush)Application.Current.FindResource("Brush.Colors.Ground"),
            Padding = new Thickness(Margin),
            Child = content,
            UseLayoutRounding = true,
        };
        var window = new Window
        {
            WindowStyle = WindowStyle.None,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            ShowActivated = false,
            WindowStartupLocation = WindowStartupLocation.Manual,
            Left = -20000,
            Top = 0,
            SizeToContent = SizeToContent.WidthAndHeight,
            Content = stage,
        };
        window.Show();
        window.Dispatcher.Invoke(DispatcherPriority.ApplicationIdle, () => window.UpdateLayout());

        var bitmap = new RenderTargetBitmap(
            (int)Math.Ceiling(stage.ActualWidth * Scale),
            (int)Math.Ceiling(stage.ActualHeight * Scale),
            96 * Scale,
            96 * Scale,
            PixelFormats.Pbgra32);
        bitmap.Render(stage);
        window.Close();
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file = File.Create(path);
        encoder.Save(file);
    }
}
