using System.ComponentModel;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;
using DailyZGT.Core.App;
using DailyZGT.Theme;

namespace DailyZGT.Priorities;

// F07. "Hecha: <título>" with Deshacer and the line that shrinks over the 5 s of the bar. The shell sets
// DataContext to the PanelState. The view shows itself while PanelState.UndoBarVisible is true, and a new
// bar (a new token) enters with rowIn.
public partial class UndoBarView : UserControl
{
    private PanelState? _panel;
    private int _shownToken;

    public UndoBarView()
    {
        InitializeComponent();
        Loaded += (_, _) => Attach();
        Unloaded += (_, _) => Detach();
        DataContextChanged += (_, _) =>
        {
            if (IsLoaded)
            {
                Attach();
            }
        };
        IsVisibleChanged += (_, e) =>
        {
            if (e.NewValue is true)
            {
                Enter();
            }
        };
    }

    private void Attach()
    {
        Detach();
        if (DataContext is not PanelState panel)
        {
            return;
        }

        _panel = panel;
        panel.PropertyChanged += OnPanelChanged;
        panel.Flow.PropertyChanged += OnFlowChanged;
        Motion.Changed += OnMotionChanged;
        Show();
    }

    private void Detach()
    {
        if (_panel is { } panel)
        {
            panel.PropertyChanged -= OnPanelChanged;
            panel.Flow.PropertyChanged -= OnFlowChanged;
            Motion.Changed -= OnMotionChanged;
        }

        _panel = null;
    }

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PanelState.UndoBarVisible))
        {
            Show();
        }
    }

    private void OnFlowChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PriorityFlow.Undo))
        {
            Show();
        }
    }

    private void OnMotionChanged(object? sender, EventArgs e) => RunLine();

    private void Show()
    {
        var undo = _panel?.Flow.Undo;
        Visibility = _panel?.UndoBarVisible == true ? Visibility.Visible : Visibility.Collapsed;
        if (undo is null)
        {
            return;
        }

        Line.Text = UiText.Current.UndoLine(undo.Title);
        AutomationProperties.SetName(Line, Line.Text);
        if (IsVisible)
        {
            Enter();
        }
    }

    private void Enter()
    {
        if (_panel?.Flow.Undo is { } undo && undo.Token != _shownToken)
        {
            _shownToken = undo.Token;
            Moves.Play(Bar, EnterKind.RowIn);
        }

        RunLine();
    }

    // The line starts from what is left of the 5 s, so a bar that shows again after Ajustes is not reset.
    private void RunLine()
    {
        if (_panel?.Flow.Undo is not { } undo)
        {
            return;
        }

        var now = _panel.Clock.Instant;
        var from = undo.LineFraction(now, Motion.IsReduced);
        Moves.Shrink(Progress, from, undo.Lifetime * undo.RemainingFraction(now));
    }

    private void OnBarSized(object sender, SizeChangedEventArgs e)
    {
        var radius = TeclaTokens.Radius.Bar;
        Bar.Clip = new RectangleGeometry(new Rect(e.NewSize), radius, radius);
    }

    private void OnUndo(object sender, RoutedEventArgs e) => _panel?.Flow.UndoDone();
}
