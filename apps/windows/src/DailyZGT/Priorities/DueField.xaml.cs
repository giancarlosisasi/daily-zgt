using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using DailyZGT.Core.App;
using DailyZGT.Core.Localization;

namespace DailyZGT.Priorities;

// F05, F09. The "Fecha límite" row: "Sin fecha", or the date with the x that clears it. "Sin fecha" asks the
// host for the next whole hour (DefaultRequested) and opens the picker on it. Closing the picker picks its
// date and time, except with Escape.
public partial class DueField : UserControl
{
    public static readonly DependencyProperty ValueProperty = DependencyProperty.Register(
        nameof(Value), typeof(DateTime?), typeof(DueField), new PropertyMetadata(null, OnValueChanged));

    public static readonly DependencyProperty ClockProperty = DependencyProperty.Register(
        nameof(Clock), typeof(UiClock), typeof(DueField), new PropertyMetadata(null));

    private readonly Texts _texts = UiText.Current;
    private bool _cancelled;
    private bool _isOpen;

    public DueField()
    {
        InitializeComponent();
        Picker.Done += (_, _) => PickerPopup.IsOpen = false;
        Picker.Cancelled += (_, _) =>
        {
            _cancelled = true;
            PickerPopup.IsOpen = false;
        };
        IsVisibleChanged += (_, e) =>
        {
            if (e.NewValue is false)
            {
                PickerPopup.IsOpen = false;
            }
        };
        Unloaded += (_, _) => PickerPopup.IsOpen = false;
    }

    public event EventHandler? DefaultRequested;

    public event EventHandler<DateTime>? Picked;

    public event EventHandler? Cleared;

    public DateTime? Value
    {
        get => (DateTime?)GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }

    public UiClock? Clock
    {
        get => (UiClock?)GetValue(ClockProperty);
        set => SetValue(ClockProperty, value);
    }

    private static void OnValueChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((DueField)d).ShowValue();

    private void ShowValue()
    {
        var value = Value;
        EmptyButton.Visibility = value is null ? Visibility.Visible : Visibility.Collapsed;
        DateRow.Visibility = value is null ? Visibility.Collapsed : Visibility.Visible;
        DateText.Text = value is { } due ? $"{_texts.DayLabel(due)} · {Texts.Clock(due)}" : string.Empty;
    }

    private void OnEmptyClick(object sender, RoutedEventArgs e)
    {
        DefaultRequested?.Invoke(this, EventArgs.Empty);
        if (Value is not null)
        {
            Dispatcher.BeginInvoke(DispatcherPriority.Input, OpenPicker);
        }
    }

    private void OnDateClick(object sender, RoutedEventArgs e) => OpenPicker();

    private void OnClearClick(object sender, RoutedEventArgs e)
    {
        PickerPopup.IsOpen = false;
        Cleared?.Invoke(this, EventArgs.Empty);
    }

    private void OpenPicker()
    {
        if (Value is not { } value || !IsVisible)
        {
            return;
        }

        _cancelled = false;
        Picker.Show(value, Clock?.Today ?? value.Date);
        PickerPopup.IsOpen = true;
    }

    private void OnPopupOpened(object? sender, EventArgs e)
    {
        _isOpen = true;
        DuePicker.SetOpen(true);
        Picker.FocusDay();
    }

    private void OnPopupClosed(object? sender, EventArgs e)
    {
        if (_isOpen)
        {
            _isOpen = false;
            DuePicker.SetOpen(false);
        }

        if (!_cancelled && Value is { } before && Picker.Value != before)
        {
            Picked?.Invoke(this, Picker.Value);
        }
    }
}
