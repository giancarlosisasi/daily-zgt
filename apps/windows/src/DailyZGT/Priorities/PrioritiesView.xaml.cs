using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Windows.Threading;
using DailyZGT.Core.App;
using DailyZGT.Theme;

namespace DailyZGT.Priorities;

// F03 to F08, F10, F12, F13. The Prioridades tab under the scope tabs. The shell sets DataContext to the
// PanelState. The view draws a PriorityListModel built on it while it is loaded.
public partial class PrioritiesView : UserControl
{
    private const double CheckLength = 9;

    private PriorityListModel? _model;
    private PanelPage? _page;

    public PrioritiesView()
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
        FormDue.DefaultRequested += (_, _) => _model?.Form.PickDefaultDue();
        FormDue.Picked += (_, due) =>
        {
            if (_model is { } model)
            {
                model.Form.DueAt = due;
            }
        };
        FormDue.Cleared += (_, _) => _model?.Form.ClearDue();
        AllDone.IsVisibleChanged += (_, e) =>
        {
            if (e.NewValue is true)
            {
                DrawCheck();
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

        _model = new PriorityListModel(panel);
        _model.Flow.PropertyChanged += OnFlowChanged;
        _model.Form.PropertyChanged += OnFormChanged;
        _model.Panel.PropertyChanged += OnPanelChanged;
        _page = panel.Page;
        Root.DataContext = _model;
        ScrollToTarget();
    }

    private void Detach()
    {
        if (_model is not { } model)
        {
            return;
        }

        model.Flow.PropertyChanged -= OnFlowChanged;
        model.Form.PropertyChanged -= OnFormChanged;
        model.Panel.PropertyChanged -= OnPanelChanged;
        model.Dispose();
        Root.DataContext = null;
        _model = null;
    }

    private void OnFlowChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PriorityFlow.ScrollTargetId))
        {
            ScrollToTarget();
        }
    }

    // F05. The form opens with the focus in the title.
    private void OnFormChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(NewPriorityForm.IsOpen) && _model?.Form.IsOpen == true)
        {
            Moves.Play(FormCard, EnterKind.RowIn);
            Dispatcher.BeginInvoke(DispatcherPriority.Input, () =>
            {
                FormTitle.Focus();
                FormTitle.CaretIndex = FormTitle.Text.Length;
            });
        }
    }

    // F02, F08, F22. A new list fades in, the list slides back after the detail view or the history, and the
    // done rows enter when Hechas opens. Opening the panel plays none of them.
    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        var panel = (PanelState)sender!;
        switch (e.PropertyName)
        {
            case nameof(PanelState.Scope):
                Moves.Play(Root, EnterKind.Fade);
                break;
            case nameof(PanelState.Page):
                var returned = panel.Page is PanelPage.Browse && _page is not PanelPage.Browse;
                _page = panel.Page;
                if (returned)
                {
                    Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () => Moves.Play(Root, EnterKind.SlideBack));
                }

                break;
            case nameof(PanelState.IsDoneOpen) when panel.IsDoneOpen:
                Moves.Play(DoneRowsPanel, EnterKind.RowIn);
                break;
        }
    }

    // F05, F07, F08, F15. After the new rows are laid out, the list scrolls to the flashed row.
    private void ScrollToTarget()
    {
        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>
        {
            if (_model is not { } model || model.Flow.ScrollTargetId is not { } id)
            {
                return;
            }

            var row = model.Rows.FirstOrDefault(item => item.Id == id);
            if (row is not null && OpenList.ItemContainerGenerator.ContainerFromItem(row) is FrameworkElement container)
            {
                container.BringIntoView();
            }

            model.Flow.ScrollWasHandled(id);
        });
    }

    // F05. Enter adds from any field of the form. Escape closes it and keeps the text.
    private void OnFormKey(object sender, KeyEventArgs e)
    {
        if (_model is not { } model)
        {
            return;
        }

        switch (e.Key)
        {
            case Key.Enter:
                e.Handled = true;
                model.Form.Submit();
                break;
            case Key.Escape:
                e.Handled = true;
                model.Form.Close();
                break;
        }
    }

    // F03, F22. The check of "Todo listo en esta lista" draws itself.
    private void DrawCheck()
    {
        var check = AllDoneCheck;
        check.BeginAnimation(Shape.StrokeDashOffsetProperty, null);
        check.StrokeDashOffset = 0;
        if (Motion.IsReduced)
        {
            return;
        }

        var animation = new DoubleAnimationUsingKeyFrames { FillBehavior = FillBehavior.Stop };
        animation.KeyFrames.Add(new DiscreteDoubleKeyFrame(CheckLength, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        animation.KeyFrames.Add(new SplineDoubleKeyFrame(0, KeyTime.FromTimeSpan(TeclaTokens.Durations.Slow), TeclaTokens.Easings.Out.Spline));
        check.BeginAnimation(Shape.StrokeDashOffsetProperty, animation);
    }
}
