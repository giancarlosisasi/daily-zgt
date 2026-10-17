using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using DailyZGT.Theme;

namespace DailyZGT.Shell;

// F22. The entry and exit motions of the shell, as the macOS PopFrame and MotionTransition define them:
// a fade with a small slide or scale. With reduced motion every one jumps to its end at once.
public static class ShellMotion
{
    private const double PopScale = 0.96;
    private const double PopOffset = 8;
    private const double SlideOffset = 18;
    private static readonly double[] RingAngles = [0, 14, -12, 8, -4, 0];

    // The panel rises from the taskbar edge; the capture window drops from the top.
    public static void Pop(FrameworkElement element, double fromY, Point origin) =>
        Play(element, 0, 1, fromY * PopOffset, 0, PopScale, 1, origin, TeclaTokens.Durations.PanelOpen, null);

    public static void Unpop(FrameworkElement element, double toY, Point origin, Action done) =>
        Play(element, 1, 0, 0, toY * PopOffset, 1, PopScale, origin, TeclaTokens.Durations.PanelOpen, done);

    // A page that enters (forward) or the list that comes back (backward).
    public static void Slide(FrameworkElement element, bool forward) =>
        Play(element, 0, 1, 0, 0, 1, 1, default, TeclaTokens.Easings.Out.Duration, null, forward ? SlideOffset : -SlideOffset);

    public static void FadeIn(FrameworkElement element) =>
        Play(element, 0, 1, 0, 0, 1, 1, default, TeclaTokens.Durations.Fast, null);

    // F15. The bell swings from a point near its top.
    public static void Ring(FrameworkElement element)
    {
        var rotate = new RotateTransform();
        element.RenderTransformOrigin = new Point(0.5, 0.1);
        element.RenderTransform = rotate;
        if (Motion.IsReduced)
        {
            return;
        }

        var step = TeclaTokens.Durations.Fast;
        var animation = new DoubleAnimationUsingKeyFrames();
        for (var index = 0; index < RingAngles.Length; index++)
        {
            animation.KeyFrames.Add(new SplineDoubleKeyFrame(RingAngles[index], KeyTime.FromTimeSpan(step * index), TeclaTokens.Easings.Out.Spline));
        }

        rotate.BeginAnimation(RotateTransform.AngleProperty, animation);
    }

    private static void Play(
        FrameworkElement element,
        double fromOpacity,
        double toOpacity,
        double fromY,
        double toY,
        double fromScale,
        double toScale,
        Point origin,
        TimeSpan duration,
        Action? done,
        double fromX = 0)
    {
        var scale = new ScaleTransform(toScale, toScale);
        var move = new TranslateTransform(0, toY);
        element.RenderTransformOrigin = origin;
        element.RenderTransform = new TransformGroup { Children = { scale, move } };
        element.BeginAnimation(UIElement.OpacityProperty, null);
        element.Opacity = toOpacity;
        if (Motion.IsReduced || duration <= TimeSpan.Zero)
        {
            done?.Invoke();
            return;
        }

        var spline = TeclaTokens.Easings.Out.Spline;
        var opacity = Animation(fromOpacity, toOpacity, duration, spline);
        if (done is not null)
        {
            opacity.Completed += (_, _) => done();
        }

        element.BeginAnimation(UIElement.OpacityProperty, opacity);
        move.BeginAnimation(TranslateTransform.XProperty, Animation(fromX, 0, duration, spline));
        move.BeginAnimation(TranslateTransform.YProperty, Animation(fromY, toY, duration, spline));
        scale.BeginAnimation(ScaleTransform.ScaleXProperty, Animation(fromScale, toScale, duration, spline));
        scale.BeginAnimation(ScaleTransform.ScaleYProperty, Animation(fromScale, toScale, duration, spline));
    }

    private static DoubleAnimationUsingKeyFrames Animation(double from, double to, TimeSpan duration, KeySpline spline)
    {
        var animation = new DoubleAnimationUsingKeyFrames();
        animation.KeyFrames.Add(new DiscreteDoubleKeyFrame(from, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        animation.KeyFrames.Add(new SplineDoubleKeyFrame(to, KeyTime.FromTimeSpan(duration), spline));
        return animation;
    }
}
