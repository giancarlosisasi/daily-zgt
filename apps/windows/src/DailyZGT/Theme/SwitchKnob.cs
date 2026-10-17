using System.Windows;

namespace DailyZGT.Theme;

// The toggle switch (F18). The knob slides KnobTravel points and the violet track fades in (F22).
// Position runs from 0 (off) to 1 (on).
public static class SwitchKnob
{
    public const double Width = 52;
    public const double Height = 30;
    public const double Inset = 3;
    public const double KnobSize = 24;
    public const double KnobRadius = 8;
    public const double WellHeight = 2;
    public const double KnobTravel = Width - KnobSize - Inset * 2;

    public static readonly DependencyProperty IsOnProperty = DependencyProperty.RegisterAttached(
        "IsOn", typeof(bool), typeof(SwitchKnob), new PropertyMetadata(false, OnChanged));

    public static readonly DependencyProperty PositionProperty = DependencyProperty.RegisterAttached(
        "Position", typeof(double), typeof(SwitchKnob), new PropertyMetadata(0.0));

    public static bool GetIsOn(DependencyObject d) => (bool)d.GetValue(IsOnProperty);

    public static void SetIsOn(DependencyObject d, bool value) => d.SetValue(IsOnProperty, value);

    public static double GetPosition(DependencyObject d) => (double)d.GetValue(PositionProperty);

    public static void SetPosition(DependencyObject d, double value) => d.SetValue(PositionProperty, value);

    private static void OnChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is FrameworkElement element)
        {
            Motion.Animate(element, PositionProperty, (bool)e.NewValue ? 1 : 0, TeclaTokens.Easings.Out);
        }
    }
}
