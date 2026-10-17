using System.Windows;
using System.Windows.Media;
using DailyZGT.Core.Domain;

namespace DailyZGT.Theme;

// Three bars of rising height. Alta fills 3 in red, Media fills 2 in orange, Baja fills 1 in gray (F04).
public sealed class LevelBars : FrameworkElement
{
    public static readonly DependencyProperty LevelProperty = DependencyProperty.Register(
        nameof(Level), typeof(PriorityLevel), typeof(LevelBars),
        new FrameworkPropertyMetadata(PriorityLevel.Medium, FrameworkPropertyMetadataOptions.AffectsRender));

    private static readonly double[] Heights = [5, 8, 11];
    private static readonly Brush Unfilled = Frozen(TeclaTokens.Panel.LvOff);
    private static readonly Brush High = Frozen(TeclaTokens.Panel.High);
    private static readonly Brush Medium = Frozen(TeclaTokens.Panel.Medium);
    private static readonly Brush Low = Frozen(TeclaTokens.Panel.Low);

    private const double BoxHeight = 11;

    public PriorityLevel Level
    {
        get => (PriorityLevel)GetValue(LevelProperty);
        set => SetValue(LevelProperty, value);
    }

    public LevelBars()
    {
        IsHitTestVisible = false;
    }

    public static int BarCount(PriorityLevel level) => level switch
    {
        PriorityLevel.High => 3,
        PriorityLevel.Medium => 2,
        _ => 1,
    };

    protected override Size MeasureOverride(Size availableSize)
        => new(Heights.Length * TeclaTokens.Size.LevelBarWidth + (Heights.Length - 1) * TeclaTokens.Size.LevelBarGap, BoxHeight);

    protected override void OnRender(DrawingContext drawingContext)
    {
        var filled = Level switch
        {
            PriorityLevel.High => High,
            PriorityLevel.Medium => Medium,
            _ => Low,
        };
        var count = BarCount(Level);
        for (var index = 0; index < Heights.Length; index++)
        {
            var x = index * (TeclaTokens.Size.LevelBarWidth + TeclaTokens.Size.LevelBarGap);
            var rect = new Rect(x, BoxHeight - Heights[index], TeclaTokens.Size.LevelBarWidth, Heights[index]);
            drawingContext.DrawRoundedRectangle(index < count ? filled : Unfilled, null, rect, TeclaTokens.Size.LevelBarRadius, TeclaTokens.Size.LevelBarRadius);
        }
    }

    private static Brush Frozen(Color color)
    {
        var brush = new SolidColorBrush(color);
        brush.Freeze();
        return brush;
    }
}
