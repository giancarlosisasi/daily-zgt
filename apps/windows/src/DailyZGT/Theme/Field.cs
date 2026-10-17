using System.Windows;
using System.Windows.Media;

namespace DailyZGT.Theme;

// Settings of the text box templates: the hint shown while the box is empty, the corner radius and
// the color of the 2 pt ring that shows while the box has the focus.
public static class Field
{
    public static readonly DependencyProperty PlaceholderProperty = DependencyProperty.RegisterAttached(
        "Placeholder", typeof(string), typeof(Field), new PropertyMetadata(string.Empty));

    public static readonly DependencyProperty RadiusProperty = DependencyProperty.RegisterAttached(
        "Radius", typeof(CornerRadius), typeof(Field), new PropertyMetadata(new CornerRadius(TeclaTokens.Radius.Input)));

    public static readonly DependencyProperty FocusBrushProperty = DependencyProperty.RegisterAttached(
        "FocusBrush", typeof(Brush), typeof(Field), new PropertyMetadata(null));

    public static string GetPlaceholder(DependencyObject d) => (string)d.GetValue(PlaceholderProperty);

    public static void SetPlaceholder(DependencyObject d, string value) => d.SetValue(PlaceholderProperty, value);

    public static CornerRadius GetRadius(DependencyObject d) => (CornerRadius)d.GetValue(RadiusProperty);

    public static void SetRadius(DependencyObject d, CornerRadius value) => d.SetValue(RadiusProperty, value);

    public static Brush? GetFocusBrush(DependencyObject d) => (Brush?)d.GetValue(FocusBrushProperty);

    public static void SetFocusBrush(DependencyObject d, Brush? value) => d.SetValue(FocusBrushProperty, value);
}
