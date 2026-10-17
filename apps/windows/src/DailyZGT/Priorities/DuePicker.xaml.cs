using System.Globalization;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using DailyZGT.Core.Localization;

namespace DailyZGT.Priorities;

// F05, F09. The due date and time picker in the popup of DueField: a month of days with the catalog's month
// and weekday names, and the hour and minute to the minute. Weeks start on Monday, like the ISO weeks of
// Semana. Enter or Listo picks, Escape leaves the date as it was.
public partial class DuePicker : UserControl
{
    private const int Weeks = 6;

    private readonly Texts _texts = UiText.Current;
    private readonly Button[] _days = new Button[Weeks * 7];
    private DateTime _month;
    private DateTime _day;
    private DateTime _today;

    public DuePicker()
    {
        InitializeComponent();
        for (var column = 0; column < 7; column++)
        {
            WeekdayRow.Children.Add(new TextBlock
            {
                Text = _texts.ShortWeekdays[(column + 1) % 7],
                Style = (Style)FindResource("Tecla.Text.Dim"),
                HorizontalAlignment = HorizontalAlignment.Center,
            });
        }

        for (var index = 0; index < _days.Length; index++)
        {
            var day = new Button { Style = (Style)FindResource("Priorities.PickerDay") };
            day.Click += OnDayClick;
            _days[index] = day;
            Days.Children.Add(day);
        }

        foreach (var box in new[] { HourBox, MinuteBox })
        {
            box.PreviewTextInput += (_, e) => e.Handled = !e.Text.All(char.IsAsciiDigit);
            box.PreviewKeyDown += OnFieldKey;
            box.MouseWheel += (_, e) => Step(box, e.Delta > 0 ? 1 : -1);
            box.LostKeyboardFocus += (_, _) => Normalize(box);
            DataObject.AddPastingHandler(box, (_, e) => e.CancelCommand());
        }

        PreviewKeyDown += OnKey;
    }

    public event EventHandler? Done;

    public event EventHandler? Cancelled;

    public DateTime Value => _day.AddHours(Read(HourBox, 23)).AddMinutes(Read(MinuteBox, 59));

    public void Show(DateTime value, DateTime today)
    {
        _today = today.Date;
        _day = value.Date;
        _month = new DateTime(value.Year, value.Month, 1, 0, 0, 0, value.Kind);
        HourBox.Text = value.Hour.ToString("00", CultureInfo.InvariantCulture);
        MinuteBox.Text = value.Minute.ToString("00", CultureInfo.InvariantCulture);
        Draw();
    }

    public void FocusDay() => _days.FirstOrDefault(day => Equals(day.Tag, "selected"))?.Focus();

    private void Draw()
    {
        MonthTitle.Text = _texts.MonthTitle(_month);
        var offset = ((int)_month.DayOfWeek + 6) % 7;
        var first = _month.AddDays(-offset);
        for (var index = 0; index < _days.Length; index++)
        {
            var date = first.AddDays(index);
            var button = _days[index];
            button.Content = date.Day.ToString(CultureInfo.InvariantCulture);
            button.DataContext = date;
            button.Tag = date == _day ? "selected" : date.Month != _month.Month ? "outside" : date == _today ? "today" : null;
            AutomationProperties.SetName(button, _texts.DayLabel(date));
        }
    }

    private void OnDayClick(object sender, RoutedEventArgs e)
    {
        var date = (DateTime)((Button)sender).DataContext;
        _day = date;
        _month = new DateTime(date.Year, date.Month, 1, 0, 0, 0, date.Kind);
        Draw();
    }

    private void OnPreviousMonth(object sender, RoutedEventArgs e) => MoveMonth(-1);

    private void OnNextMonth(object sender, RoutedEventArgs e) => MoveMonth(1);

    // The selected day moves with the month and keeps its number when the month has it.
    private void MoveMonth(int months)
    {
        _month = _month.AddMonths(months);
        var day = Math.Min(_day.Day, DateTime.DaysInMonth(_month.Year, _month.Month));
        _day = new DateTime(_month.Year, _month.Month, day, 0, 0, 0, _month.Kind);
        Draw();
    }

    private void OnDone(object sender, RoutedEventArgs e) => Done?.Invoke(this, EventArgs.Empty);

    private void OnKey(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Enter:
                e.Handled = true;
                Done?.Invoke(this, EventArgs.Empty);
                break;
            case Key.Escape:
                e.Handled = true;
                Cancelled?.Invoke(this, EventArgs.Empty);
                break;
        }
    }

    private void OnFieldKey(object sender, KeyEventArgs e)
    {
        var step = e.Key switch
        {
            Key.Up => 1,
            Key.Down => -1,
            _ => 0,
        };
        if (step != 0)
        {
            e.Handled = true;
            Step((TextBox)sender, step);
        }
    }

    private void Step(TextBox box, int step)
    {
        var max = box == HourBox ? 23 : 59;
        var value = (Read(box, max) + step + max + 1) % (max + 1);
        box.Text = value.ToString("00", CultureInfo.InvariantCulture);
        box.CaretIndex = box.Text.Length;
    }

    private void Normalize(TextBox box) =>
        box.Text = Read(box, box == HourBox ? 23 : 59).ToString("00", CultureInfo.InvariantCulture);

    private static int Read(TextBox box, int max) =>
        int.TryParse(box.Text, NumberStyles.None, CultureInfo.InvariantCulture, out var value) ? Math.Clamp(value, 0, max) : 0;
}
