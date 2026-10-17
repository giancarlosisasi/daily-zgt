using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using DailyZGT.Core.App;

namespace DailyZGT.Priorities;

// F09 to F11, F14. The detail view of PanelState.Detail. The shell sets DataContext to the PanelState and
// shows the view while the page is Detail. Each opened priority slides in (F22).
public partial class DetailView : UserControl
{
    private PanelState? _panel;
    private DetailItem? _item;

    public DetailView()
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
        DetailDue.DefaultRequested += (_, _) => _item?.Model.PickDefaultDue();
        DetailDue.Picked += (_, due) => _item?.Model.SetDue(due);
        DetailDue.Cleared += (_, _) => _item?.Model.SetDue(null);
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
        Show(panel.Detail);
    }

    private void Detach()
    {
        if (_panel is { } panel)
        {
            panel.PropertyChanged -= OnPanelChanged;
        }

        _panel = null;
        Show(null);
    }

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PanelState.Detail) && _panel?.Detail?.Id != _item?.Model.Id)
        {
            Show(_panel?.Detail);
            if (_item is not null)
            {
                Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () => Moves.Play(Root, EnterKind.SlideIn));
            }
        }
    }

    private void Show(PriorityDetailModel? model)
    {
        _item?.Dispose();
        _item = model is null || _panel is null ? null : new DetailItem(_panel, model);
        Root.DataContext = _item;
    }

    private void OnTitleFocus(object sender, KeyboardFocusChangedEventArgs e) => _item?.Model.BeginTitleEdit();

    // A click outside the field, a tab or the panel losing the focus saves the title.
    private void OnTitleBlur(object sender, KeyboardFocusChangedEventArgs e)
    {
        if (_item?.Model is { TitleState: TitleEditState.Editing } model)
        {
            model.CommitTitle();
        }
    }

    // F09. Enter saves, Escape puts the saved title back.
    private void OnTitleKey(object sender, KeyEventArgs e)
    {
        if (_item?.Model is not { } model)
        {
            return;
        }

        switch (e.Key)
        {
            case Key.Enter:
                e.Handled = true;
                model.CommitTitle();
                LeaveTitle();
                break;
            case Key.Escape:
                e.Handled = true;
                model.DiscardTitle();
                LeaveTitle();
                break;
        }
    }

    // A click on a part of the view that takes no focus still ends the title edit, like a click outside on macOS.
    private void OnRootMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (TitleBox.IsKeyboardFocusWithin && !TitleBox.IsMouseOver)
        {
            LeaveTitle();
        }
    }

    // F11. The note saves when its box loses the focus, not only 400 ms after the last key.
    private void OnNoteBlur(object sender, KeyboardFocusChangedEventArgs e) => _item?.Note.Flush();

    private void LeaveTitle()
    {
        Keyboard.ClearFocus();
        if (TitleBox.IsKeyboardFocusWithin)
        {
            Root.Focus();
        }
    }
}
