using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;

namespace DailyZGT.Theme;

// Draws one of the Icon.* geometries (Theme/Icons.xaml, 256 view box) at Size x Size in the inherited
// text color, like IconView with a template image on macOS.
public sealed class IconView : FrameworkElement
{
    public static readonly DependencyProperty KindProperty = DependencyProperty.Register(
        nameof(Kind), typeof(string), typeof(IconView),
        new FrameworkPropertyMetadata(string.Empty, FrameworkPropertyMetadataOptions.AffectsRender, OnKindChanged));

    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(double), typeof(IconView),
        new FrameworkPropertyMetadata(13.0, FrameworkPropertyMetadataOptions.AffectsMeasure | FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty ForegroundProperty = TextElement.ForegroundProperty.AddOwner(
        typeof(IconView),
        new FrameworkPropertyMetadata(Brushes.White, FrameworkPropertyMetadataOptions.AffectsRender | FrameworkPropertyMetadataOptions.Inherits));

    private const double ViewBox = 256;

    private Geometry? geometry;

    public string Kind
    {
        get => (string)GetValue(KindProperty);
        set => SetValue(KindProperty, value);
    }

    public double Size
    {
        get => (double)GetValue(SizeProperty);
        set => SetValue(SizeProperty, value);
    }

    public Brush Foreground
    {
        get => (Brush)GetValue(ForegroundProperty);
        set => SetValue(ForegroundProperty, value);
    }

    public IconView()
    {
        IsHitTestVisible = false;
        SnapsToDevicePixels = false;
    }

    protected override Size MeasureOverride(Size availableSize) => new(Size, Size);

    protected override void OnRender(DrawingContext drawingContext)
    {
        geometry ??= Resolve(Kind);
        if (geometry is null)
        {
            return;
        }

        var scale = Size / ViewBox;
        drawingContext.PushTransform(new ScaleTransform(scale, scale));
        drawingContext.DrawGeometry(Foreground, null, geometry);
        drawingContext.Pop();
    }

    private static void OnKindChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        ((IconView)d).geometry = null;
    }

    private static Geometry? Resolve(string kind)
        => string.IsNullOrEmpty(kind) ? null : Application.Current?.TryFindResource("Icon." + kind) as Geometry;
}
