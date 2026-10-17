using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using DailyZGT.Theme;

namespace DailyZGT.Priorities;

public enum EnterKind { RowIn, Fade, SlideIn, SlideBack }

// F22. The motion of the Priorities views, the macOS rowIn, rowOut, fade, slide and caret. Every animation
// checks Theme.Motion.IsReduced, so with "Animation effects" off each element jumps to its end state.
public static class Moves
{
    private const double RowInOffset = 4;
    private const double RowOutOffset = 28;
    private const double SlideOffset = 18;
    private const double CaretOpenDegrees = 90;

    private static readonly KeySpline Linear = new(0, 0, 1, 1);
    private static readonly KeySpline EaseInOut = new(0.42, 0, 0.58, 1);

    // Plays rowIn when the element loads: a row added after the first draw, a confirm bar, opened subtasks.
    public static readonly DependencyProperty EnterOnLoadProperty = DependencyProperty.RegisterAttached(
        "EnterOnLoad", typeof(bool), typeof(Moves), new PropertyMetadata(false, OnEnterOnLoadChanged));

    // F07. The row slides out to the right and fades while it waits for the store write.
    public static readonly DependencyProperty LeavingProperty = DependencyProperty.RegisterAttached(
        "Leaving", typeof(bool), typeof(Moves), new PropertyMetadata(false, OnLeavingChanged));

    // F04, F08. The caret turns 90 degrees while its section is open.
    public static readonly DependencyProperty TurnedProperty = DependencyProperty.RegisterAttached(
        "Turned", typeof(bool), typeof(Moves), new PropertyMetadata(false, OnTurnedChanged));

    public static bool GetEnterOnLoad(DependencyObject d) => (bool)d.GetValue(EnterOnLoadProperty);

    public static void SetEnterOnLoad(DependencyObject d, bool value) => d.SetValue(EnterOnLoadProperty, value);

    public static bool GetLeaving(DependencyObject d) => (bool)d.GetValue(LeavingProperty);

    public static void SetLeaving(DependencyObject d, bool value) => d.SetValue(LeavingProperty, value);

    public static bool GetTurned(DependencyObject d) => (bool)d.GetValue(TurnedProperty);

    public static void SetTurned(DependencyObject d, bool value) => d.SetValue(TurnedProperty, value);

    public static void Play(FrameworkElement element, EnterKind kind)
    {
        var (x, y, duration, spline) = kind switch
        {
            EnterKind.RowIn => (0.0, -RowInOffset, TeclaTokens.Easings.Out.Duration, TeclaTokens.Easings.Out.Spline),
            EnterKind.SlideIn => (SlideOffset, 0.0, TeclaTokens.Durations.Base, TeclaTokens.Easings.Out.Spline),
            EnterKind.SlideBack => (-SlideOffset, 0.0, TeclaTokens.Durations.Base, TeclaTokens.Easings.Out.Spline),
            _ => (0.0, 0.0, TeclaTokens.Durations.Fast, EaseInOut),
        };
        var shift = Shift(element);
        Run(element, UIElement.OpacityProperty, 0, 1, duration, spline);
        Run(shift, TranslateTransform.XProperty, x, 0, duration, spline);
        Run(shift, TranslateTransform.YProperty, y, 0, duration, spline);
    }

    // F07. The undo line: the width fraction goes from `from` to 0 in `duration`, at a steady pace.
    public static void Shrink(FrameworkElement line, double from, TimeSpan duration)
    {
        if (line.RenderTransform is not ScaleTransform scale || scale.IsFrozen)
        {
            scale = new ScaleTransform();
            line.RenderTransform = scale;
        }

        if (Motion.IsReduced || duration <= TimeSpan.Zero)
        {
            scale.BeginAnimation(ScaleTransform.ScaleXProperty, null);
            scale.ScaleX = from;
            return;
        }

        Run(scale, ScaleTransform.ScaleXProperty, from, 0, duration, Linear);
    }

    private static void OnEnterOnLoadChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is FrameworkElement element && e.NewValue is true)
        {
            element.Loaded += PlayOnce;
        }
    }

    private static void PlayOnce(object sender, RoutedEventArgs e)
    {
        var element = (FrameworkElement)sender;
        element.Loaded -= PlayOnce;
        Play(element, EnterKind.RowIn);
    }

    private static void OnLeavingChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not FrameworkElement element)
        {
            return;
        }

        var leaving = (bool)e.NewValue;
        element.IsHitTestVisible = !leaving;
        var shift = Shift(element);
        var duration = leaving ? TeclaTokens.Durations.Slow : TimeSpan.Zero;
        var spline = TeclaTokens.Easings.Out.Spline;
        Run(element, UIElement.OpacityProperty, element.Opacity, leaving ? 0 : 1, duration, spline);
        Run(shift, TranslateTransform.XProperty, shift.X, leaving ? RowOutOffset : 0, duration, spline);
    }

    private static void OnTurnedChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not FrameworkElement element)
        {
            return;
        }

        if (element.RenderTransform is not RotateTransform turn || turn.IsFrozen)
        {
            turn = new RotateTransform();
            element.RenderTransform = turn;
            element.RenderTransformOrigin = new Point(0.5, 0.5);
        }

        var duration = element.IsLoaded ? TeclaTokens.Easings.Out.Duration : TimeSpan.Zero;
        Run(turn, RotateTransform.AngleProperty, turn.Angle, (bool)e.NewValue ? CaretOpenDegrees : 0, duration, TeclaTokens.Easings.Out.Spline);
    }

    private static TranslateTransform Shift(FrameworkElement element)
    {
        if (element.RenderTransform is TranslateTransform shift && !shift.IsFrozen)
        {
            return shift;
        }

        shift = new TranslateTransform();
        element.RenderTransform = shift;
        return shift;
    }

    // The base value is set to the end first, so a stopped or skipped animation leaves the end state.
    private static void Run(IAnimatable target, DependencyProperty property, double from, double to, TimeSpan duration, KeySpline spline)
    {
        var owner = (DependencyObject)target;
        target.BeginAnimation(property, null);
        owner.SetValue(property, to);
        if (Motion.IsReduced || duration <= TimeSpan.Zero || from.Equals(to))
        {
            return;
        }

        var animation = new DoubleAnimationUsingKeyFrames { FillBehavior = FillBehavior.Stop };
        animation.KeyFrames.Add(new DiscreteDoubleKeyFrame(from, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        animation.KeyFrames.Add(new SplineDoubleKeyFrame(to, KeyTime.FromTimeSpan(duration), spline));
        target.BeginAnimation(property, animation);
    }
}
