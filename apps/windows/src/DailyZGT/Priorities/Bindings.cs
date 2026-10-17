using System.Globalization;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Markup;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;

namespace DailyZGT.Priorities;

// {p:Text Cancel} reads one plain string of UiText.Current. A wrong name fails when the view loads.
[MarkupExtensionReturnType(typeof(string))]
public sealed class TextExtension(string key) : MarkupExtension
{
    public override object ProvideValue(IServiceProvider serviceProvider) =>
        typeof(Texts).GetProperty(key, BindingFlags.Public | BindingFlags.Instance)?.GetValue(UiText.Current) as string
        ?? throw new ArgumentException($"Texts has no string named {key}.", nameof(key));
}

public sealed class RelayCommand(Action execute) : ICommand
{
    public event EventHandler? CanExecuteChanged
    {
        add { }
        remove { }
    }

    public bool CanExecute(object? parameter) => true;

    public void Execute(object? parameter) => execute();
}

// Draws Template only while the content is set. A plain ContentTemplate would draw it for null too.
public sealed class WhenSet : DataTemplateSelector
{
    public DataTemplate? Template { get; set; }

    public override DataTemplate? SelectTemplate(object? item, DependencyObject container) => item is null ? null : Template;
}

// True, a non-empty string or any other non-null value shows the element.
public sealed class ShownConverter : IValueConverter
{
    public static readonly ShownConverter Instance = new();
    public static readonly ShownConverter Inverted = new() { Invert = true };

    public bool Invert { get; init; }

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var shown = value switch
        {
            bool flag => flag,
            string text => text.Length > 0,
            int count => count > 0,
            null => false,
            _ => true,
        };
        return shown != Invert ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

// A segment key is checked when the bound value equals its ConverterParameter. Checking it writes the parameter back.
public sealed class IsValueConverter : IValueConverter
{
    public static readonly IsValueConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) => Equals(value, parameter);

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is true ? parameter : Binding.DoNothing;
}

// F12, F13. The Tecla chip style of a due or since chip.
public sealed class ChipStyleConverter : IValueConverter
{
    public static readonly ChipStyleConverter Instance = new();

    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var key = value switch
        {
            DueTone.Overdue => "Tecla.Chip.Overdue",
            DueTone.Soon => "Tecla.Chip.Soon",
            _ => "Tecla.Chip.Later",
        };
        return Application.Current.TryFindResource(key);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
