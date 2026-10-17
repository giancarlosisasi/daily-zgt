using System.Windows;
using System.Windows.Media;

namespace DailyZGT.Theme;

// The state behind a Tecla key: a raised face with a dark side under it. Pressing the key moves the
// face down by Travel and hides the side. The styles set Pressed (from IsPressed) and StaysDown (a
// checked checkbox). Templates read Offset, SideOpacity and Tint. With reduced motion the face does
// not travel while pressed. A tint shows instead (KeyPress.showsPressedTint on macOS).
public static class KeyFace
{
    public static readonly DependencyProperty PressedProperty = DependencyProperty.RegisterAttached(
        "Pressed", typeof(bool), typeof(KeyFace), new PropertyMetadata(false, OnInputChanged));

    public static readonly DependencyProperty StaysDownProperty = DependencyProperty.RegisterAttached(
        "StaysDown", typeof(bool), typeof(KeyFace), new PropertyMetadata(false, OnInputChanged));

    public static readonly DependencyProperty OffsetProperty = DependencyProperty.RegisterAttached(
        "Offset", typeof(double), typeof(KeyFace), new PropertyMetadata(0.0));

    public static readonly DependencyProperty SideOpacityProperty = DependencyProperty.RegisterAttached(
        "SideOpacity", typeof(double), typeof(KeyFace), new PropertyMetadata(1.0));

    public static readonly DependencyProperty TintProperty = DependencyProperty.RegisterAttached(
        "Tint", typeof(double), typeof(KeyFace), new PropertyMetadata(0.0));

    public static readonly DependencyProperty SideProperty = DependencyProperty.RegisterAttached(
        "Side", typeof(Brush), typeof(KeyFace), new PropertyMetadata(null));

    public static readonly DependencyProperty SideHeightProperty = DependencyProperty.RegisterAttached(
        "SideHeight", typeof(double), typeof(KeyFace), new PropertyMetadata(TeclaTokens.Key.PanelSideHeight));

    public static readonly DependencyProperty TravelProperty = DependencyProperty.RegisterAttached(
        "Travel", typeof(double), typeof(KeyFace), new PropertyMetadata(TeclaTokens.Key.PanelTravel));

    public static readonly DependencyProperty RadiusProperty = DependencyProperty.RegisterAttached(
        "Radius", typeof(CornerRadius), typeof(KeyFace), new PropertyMetadata(new CornerRadius(TeclaTokens.Radius.PanelControl)));

    public static bool GetPressed(DependencyObject d) => (bool)d.GetValue(PressedProperty);

    public static void SetPressed(DependencyObject d, bool value) => d.SetValue(PressedProperty, value);

    public static bool GetStaysDown(DependencyObject d) => (bool)d.GetValue(StaysDownProperty);

    public static void SetStaysDown(DependencyObject d, bool value) => d.SetValue(StaysDownProperty, value);

    public static double GetOffset(DependencyObject d) => (double)d.GetValue(OffsetProperty);

    public static void SetOffset(DependencyObject d, double value) => d.SetValue(OffsetProperty, value);

    public static double GetSideOpacity(DependencyObject d) => (double)d.GetValue(SideOpacityProperty);

    public static void SetSideOpacity(DependencyObject d, double value) => d.SetValue(SideOpacityProperty, value);

    public static double GetTint(DependencyObject d) => (double)d.GetValue(TintProperty);

    public static void SetTint(DependencyObject d, double value) => d.SetValue(TintProperty, value);

    public static Brush? GetSide(DependencyObject d) => (Brush?)d.GetValue(SideProperty);

    public static void SetSide(DependencyObject d, Brush? value) => d.SetValue(SideProperty, value);

    public static double GetSideHeight(DependencyObject d) => (double)d.GetValue(SideHeightProperty);

    public static void SetSideHeight(DependencyObject d, double value) => d.SetValue(SideHeightProperty, value);

    public static double GetTravel(DependencyObject d) => (double)d.GetValue(TravelProperty);

    public static void SetTravel(DependencyObject d, double value) => d.SetValue(TravelProperty, value);

    public static CornerRadius GetRadius(DependencyObject d) => (CornerRadius)d.GetValue(RadiusProperty);

    public static void SetRadius(DependencyObject d, CornerRadius value) => d.SetValue(RadiusProperty, value);

    private static void OnInputChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not FrameworkElement element)
        {
            return;
        }

        var pressed = GetPressed(d);
        var down = GetStaysDown(d) || (pressed && !Motion.IsReduced);
        Motion.Animate(element, OffsetProperty, down ? GetTravel(d) : 0, TeclaTokens.Easings.Press);
        Motion.Animate(element, SideOpacityProperty, down ? 0 : 1, TeclaTokens.Easings.Press);
        element.SetValue(TintProperty, pressed && Motion.IsReduced ? 1.0 : 0.0);
    }
}
