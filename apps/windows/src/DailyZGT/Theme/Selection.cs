using System.Windows;

namespace DailyZGT.Theme;

// A segmented tab button fades its raised face in when it becomes the selected one (F22: fade, 0.18 s).
public static class Selection
{
    public static readonly DependencyProperty OnProperty = DependencyProperty.RegisterAttached(
        "On", typeof(bool), typeof(Selection), new PropertyMetadata(false, OnChanged));

    public static readonly DependencyProperty AmountProperty = DependencyProperty.RegisterAttached(
        "Amount", typeof(double), typeof(Selection), new PropertyMetadata(0.0));

    public static bool GetOn(DependencyObject d) => (bool)d.GetValue(OnProperty);

    public static void SetOn(DependencyObject d, bool value) => d.SetValue(OnProperty, value);

    public static double GetAmount(DependencyObject d) => (double)d.GetValue(AmountProperty);

    public static void SetAmount(DependencyObject d, double value) => d.SetValue(AmountProperty, value);

    private static void OnChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is FrameworkElement element)
        {
            Motion.Animate(element, AmountProperty, (bool)e.NewValue ? 1 : 0, TeclaTokens.Durations.Fast);
        }
    }
}
