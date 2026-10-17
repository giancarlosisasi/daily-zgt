using System.Windows;
using System.Windows.Controls;

namespace DailyZGT.Priorities;

// F05, F09, F15. The bell and the alert text, or the struck bell, "Las alertas están desactivadas." and
// "Abrir ajustes" when Windows turned the notifications off and the priority has a due date.
public partial class AlertHint : UserControl
{
    public static readonly DependencyProperty TextProperty = DependencyProperty.Register(
        nameof(Text), typeof(string), typeof(AlertHint), new PropertyMetadata(string.Empty));

    public static readonly DependencyProperty HasDueProperty = DependencyProperty.Register(
        nameof(HasDue), typeof(bool), typeof(AlertHint), new PropertyMetadata(true, OnStateChanged));

    public static readonly DependencyProperty AlertsOffProperty = AlertsNotice.IsOffProperty.AddOwner(
        typeof(AlertHint), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.Inherits, OnStateChanged));

    public AlertHint()
    {
        InitializeComponent();
        Show();
    }

    public string Text
    {
        get => (string)GetValue(TextProperty);
        set => SetValue(TextProperty, value);
    }

    public bool HasDue
    {
        get => (bool)GetValue(HasDueProperty);
        set => SetValue(HasDueProperty, value);
    }

    public bool AlertsOff
    {
        get => (bool)GetValue(AlertsOffProperty);
        set => SetValue(AlertsOffProperty, value);
    }

    private static void OnStateChanged(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((AlertHint)d).Show();

    private void Show()
    {
        if (Bell is null)
        {
            return;
        }

        var off = AlertsOff && HasDue;
        Bell.Kind = off ? "BellSlash" : "Bell";
        Line.Visibility = off ? Visibility.Collapsed : Visibility.Visible;
        OffLine.Visibility = off ? Visibility.Visible : Visibility.Collapsed;
    }
}
