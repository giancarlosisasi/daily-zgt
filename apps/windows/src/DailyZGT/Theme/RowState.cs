using System.Windows;

namespace DailyZGT.Theme;

// The row surface sets Hovered while the pointer is over it. The inherited value lets the trash
// button inside the row show itself (F04). Highlighted is the yellow flash after Deshacer (F07).
public static class RowState
{
    public static readonly DependencyProperty HoveredProperty = DependencyProperty.RegisterAttached(
        "Hovered", typeof(bool), typeof(RowState), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.Inherits));

    public static readonly DependencyProperty HighlightedProperty = DependencyProperty.RegisterAttached(
        "Highlighted", typeof(bool), typeof(RowState), new PropertyMetadata(false));

    public static bool GetHovered(DependencyObject d) => (bool)d.GetValue(HoveredProperty);

    public static void SetHovered(DependencyObject d, bool value) => d.SetValue(HoveredProperty, value);

    public static bool GetHighlighted(DependencyObject d) => (bool)d.GetValue(HighlightedProperty);

    public static void SetHighlighted(DependencyObject d, bool value) => d.SetValue(HighlightedProperty, value);
}
