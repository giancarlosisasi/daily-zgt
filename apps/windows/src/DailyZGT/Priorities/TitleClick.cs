using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using DailyZGT.Core.App;

namespace DailyZGT.Priorities;

// F04. A click on the title or the data line runs Command. A drag, a pointer that moved more than 3 points,
// or a selection in the title does not, so the title can be copied (TitleClickRule).
public static class TitleClick
{
    public static readonly DependencyProperty CommandProperty = DependencyProperty.RegisterAttached(
        "Command", typeof(ICommand), typeof(TitleClick), new PropertyMetadata(null, OnCommandChanged));

    private static readonly DependencyProperty DownProperty = DependencyProperty.RegisterAttached(
        "Down", typeof(Point?), typeof(TitleClick), new PropertyMetadata(null));

    public static ICommand? GetCommand(DependencyObject d) => (ICommand?)d.GetValue(CommandProperty);

    public static void SetCommand(DependencyObject d, ICommand? value) => d.SetValue(CommandProperty, value);

    private static void OnCommandChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not UIElement element)
        {
            return;
        }

        element.PreviewMouseLeftButtonDown -= OnDown;
        element.PreviewMouseLeftButtonUp -= OnUp;
        if (e.NewValue is not null)
        {
            element.PreviewMouseLeftButtonDown += OnDown;
            element.PreviewMouseLeftButtonUp += OnUp;
        }
    }

    private static void OnDown(object sender, MouseButtonEventArgs e)
    {
        var element = (UIElement)sender;
        element.SetValue(DownProperty, e.ClickCount == 1 ? e.GetPosition(element) : null);
    }

    private static void OnUp(object sender, MouseButtonEventArgs e)
    {
        var element = (UIElement)sender;
        if (element.GetValue(DownProperty) is not Point down)
        {
            return;
        }

        element.SetValue(DownProperty, null);
        var up = e.GetPosition(element);
        var selection = element is TextBox box ? box.SelectionLength : 0;
        if (TitleClickRule.ShouldOpen((down.X, down.Y), (up.X, up.Y), selection) && GetCommand(element) is { } command)
        {
            command.Execute(null);
        }
    }
}
