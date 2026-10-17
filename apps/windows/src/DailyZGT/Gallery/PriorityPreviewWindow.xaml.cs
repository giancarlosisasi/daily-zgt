using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Platform;
using DailyZGT.Priorities;

namespace DailyZGT.Gallery;

// A stand-in for the panel shell: the Priorities views on a real PanelState over demo rows, with buttons
// that switch pages and settings. A state name puts the panel in one situation for a snapshot.
public partial class PriorityPreviewWindow : Window
{
    public static readonly IReadOnlyList<string> States =
    [
        "list", "confirm", "highlight", "form", "form-off", "form-limit", "picker", "detail", "detail-off",
        "detail-confirm", "history", "undo", "week", "all-done", "nothing",
    ];

    private readonly PreviewData _data;
    private int _deactivations;

    public PriorityPreviewWindow()
    {
        InitializeComponent();
        _data = new PreviewData(SynchronizationContext.Current);
        var panel = _data.Panel;
        foreach (var view in new FrameworkElement[] { ListPage, DetailPage, HistoryPage, UndoBar })
        {
            view.DataContext = panel;
        }

        panel.PropertyChanged += OnPanelChanged;
        CommandBindings.Add(new CommandBinding(AlertsNotice.OpenSettings, (_, _) => new WindowsSettingsOpener().OpenNotifications()));
        Activated += (_, _) => panel.OnActivated();
        Deactivated += (_, _) =>
        {
            _deactivations++;
            panel.OnDeactivated();
            ShowStatus();
        };
        Closed += (_, _) => _data.Dispose();
        ShowPage();
        ShowStatus();
    }

    public FrameworkElement SnapshotTarget => Stage;

    public void Apply(string state)
    {
        var panel = _data.Panel;
        switch (state)
        {
            case "confirm":
                panel.Flow.ToggleSubtasks(_data.ProposalId);
                panel.Flow.ToggleConfirmation(_data.ProposalId);
                break;
            case "highlight":
                panel.Flow.Flash(_data.ProposalId);
                break;
            case "form":
            case "form-off":
            case "picker":
                panel.Form.Open();
                panel.Form.Title = "Llamar a Marta";
                panel.Form.Level = PriorityLevel.High;
                panel.Form.PickDefaultDue();
                AlertsNotice.SetIsOff(PanelHost, state == "form-off");
                if (state == "picker")
                {
                    var picker = new DuePicker();
                    picker.Show(panel.Form.DueAt!.Value, _data.Clock.Today);
                    PickerSample.Content = picker;
                }

                break;
            case "form-limit":
                panel.TodayLimitIsOn = true;
                _data.Store.AddPriority("Escribir a Lucía", PriorityList.Today);
                panel.Form.Open();
                panel.Form.Title = "Una prioridad más";
                panel.Form.Submit();
                break;
            case "detail":
            case "detail-off":
                panel.OpenDetail(_data.ProposalId);
                AlertsNotice.SetIsOff(PanelHost, state == "detail-off");
                break;
            case "detail-confirm":
                panel.OpenDetail(_data.ProposalId);
                panel.Flow.ToggleConfirmation(_data.ProposalId);
                break;
            case "history":
                panel.OpenHistory();
                break;
            case "undo":
                panel.Flow.ConfirmDone(_data.ContractId, DoneOrigin.Detail);
                break;
            case "week":
                panel.SelectScope(PriorityList.Week);
                break;
            case "all-done":
                panel.SelectScope(PriorityList.Week);
                foreach (var open in _data.Store.OpenPriorities(PriorityList.Week))
                {
                    _data.Store.MarkDone(open.Id);
                }

                break;
            case "nothing":
                panel.SelectScope(PriorityList.Week);
                foreach (var priority in _data.Store.Snapshot.Open.Concat(_data.Store.Snapshot.Done).Where(p => p.List == PriorityList.Week).ToList())
                {
                    _data.Store.Delete(priority.Id);
                }

                break;
        }
    }

    public void SaveSnapshot(string path)
    {
        const double scale = 2;
        const double margin = 24;
        var target = SnapshotTarget;
        var area = new Rect(-margin, -margin, target.ActualWidth + 2 * margin, target.ActualHeight + 2 * margin);
        var bitmap = new RenderTargetBitmap(
            (int)Math.Ceiling(area.Width * scale),
            (int)Math.Ceiling(area.Height * scale),
            96 * scale,
            96 * scale,
            PixelFormats.Pbgra32);
        var stage = new DrawingVisual();
        using (var context = stage.RenderOpen())
        {
            var page = new Rect(area.Size);
            context.DrawRectangle((Brush)FindResource("Brush.Colors.Ground"), null, page);
            context.DrawRectangle(new VisualBrush(target) { ViewboxUnits = BrushMappingMode.Absolute, Viewbox = area }, null, page);
        }

        bitmap.Render(stage);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        using var file = File.Create(path);
        encoder.Save(file);
    }

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PanelState.Page))
        {
            ShowPage();
        }
    }

    private void ShowPage()
    {
        var page = _data.Panel.Page;
        ListPage.Visibility = page is PanelPage.Browse ? Visibility.Visible : Visibility.Collapsed;
        DetailPage.Visibility = page is PanelPage.Detail ? Visibility.Visible : Visibility.Collapsed;
        HistoryPage.Visibility = page is PanelPage.History ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ShowStatus() =>
        Status.Text = $"Desactivaciones: {_deactivations}\n"
            + $"Alertas apagadas: {AlertsNotice.GetIsOff(PanelHost)}\nMovimiento reducido: {Theme.Motion.IsReduced}\n"
            + $"Límite: {_data.Panel.TodayLimitIsOn}";

    private void OnList(object sender, RoutedEventArgs e)
    {
        _data.Panel.CloseDetail();
        _data.Panel.CloseHistory();
    }

    private void OnDetail(object sender, RoutedEventArgs e) =>
        _data.Panel.OpenDetail(_data.Store.OpenPriorities(_data.Panel.Scope).FirstOrDefault()?.Id ?? _data.ProposalId);

    private void OnHistory(object sender, RoutedEventArgs e) => _data.Panel.OpenHistory();

    private void OnScope(object sender, RoutedEventArgs e) =>
        _data.Panel.SelectScope(_data.Panel.Scope == PriorityList.Today ? PriorityList.Week : PriorityList.Today);

    private void OnAlerts(object sender, RoutedEventArgs e)
    {
        AlertsNotice.SetIsOff(PanelHost, !AlertsNotice.GetIsOff(PanelHost));
        ShowStatus();
    }

    private void OnMotion(object sender, RoutedEventArgs e)
    {
        _data.Motion.Set(!Theme.Motion.IsReduced);
        ShowStatus();
    }

    private void OnLimit(object sender, RoutedEventArgs e)
    {
        _data.Panel.TodayLimitIsOn = !_data.Panel.TodayLimitIsOn;
        ShowStatus();
    }
}
