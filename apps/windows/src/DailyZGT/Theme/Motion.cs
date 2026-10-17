using System.Windows;
using System.Windows.Media.Animation;

namespace DailyZGT.Theme;

// F22. One switch for all motion. The Windows "Animation effects" setting feeds IsReduced from
// outside this folder. Every animation in the theme goes through Animate or Play, so a reduced
// run jumps straight to the final value.
public static class Motion
{
    private static readonly KeySpline EaseInOut = Freeze(new KeySpline(0.42, 0, 0.58, 1));

    private static bool isReduced;

    public static bool IsReduced
    {
        get => isReduced;
        set
        {
            if (isReduced == value)
            {
                return;
            }

            isReduced = value;
            Changed?.Invoke(null, EventArgs.Empty);
        }
    }

    public static event EventHandler? Changed;

    public static void Animate(FrameworkElement element, DependencyProperty property, double to, TeclaEasing easing)
        => Animate(element, property, to, easing.Duration, easing.Spline);

    public static void Animate(FrameworkElement element, DependencyProperty property, double to, TimeSpan duration, KeySpline? spline = null)
    {
        if (IsReduced || !element.IsLoaded || duration <= TimeSpan.Zero)
        {
            element.BeginAnimation(property, null);
            element.SetValue(property, to);
            return;
        }

        var animation = new DoubleAnimationUsingKeyFrames { FillBehavior = FillBehavior.HoldEnd };
        animation.KeyFrames.Add(new SplineDoubleKeyFrame(to, KeyTime.FromTimeSpan(duration), spline ?? EaseInOut));
        animation.Completed += (_, _) =>
        {
            element.SetValue(property, to);
            element.BeginAnimation(property, null);
        };
        element.BeginAnimation(property, animation);
    }

    public static void Play(Storyboard storyboard, FrameworkElement scope)
    {
        storyboard.Begin(scope, true);
        if (IsReduced)
        {
            storyboard.SkipToFill(scope);
        }
    }

    private static KeySpline Freeze(KeySpline spline)
    {
        spline.Freeze();
        return spline;
    }
}
