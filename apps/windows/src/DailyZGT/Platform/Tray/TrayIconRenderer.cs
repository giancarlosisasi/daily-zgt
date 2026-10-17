using System.Globalization;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace DailyZGT.Platform;

public static class TrayIconRenderer
{
    private const double ViewBox = 24;
    private const double StrokeWidth = 2;
    private const double BadgeScale = 0.75;

    public static BitmapSource Render(int pixels, int? count, bool lightTaskbar)
    {
        var foreground = lightTaskbar ? Colors.Black : Colors.White;
        var badgeText = TrayBadge.Text(count);
        var crosshairPixels = badgeText is null ? pixels : (int)Math.Round(pixels * BadgeScale) & ~1;

        var visual = new DrawingVisual();
        TextOptions.SetTextFormattingMode(visual, TextFormattingMode.Display);
        TextOptions.SetTextRenderingMode(visual, TextRenderingMode.Grayscale);
        using (var dc = visual.RenderOpen())
        {
            DrawCrosshair(dc, crosshairPixels, new SolidColorBrush(foreground));
            if (badgeText is not null)
            {
                DrawBadge(dc, pixels, badgeText, foreground, lightTaskbar ? Colors.White : Colors.Black);
            }
        }

        var bitmap = new RenderTargetBitmap(pixels, pixels, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(visual);
        bitmap.Freeze();
        return bitmap;
    }

    private static void DrawCrosshair(DrawingContext dc, int pixels, Brush brush)
    {
        var scale = pixels / ViewBox;
        var stroke = Math.Max(1, Math.Round(StrokeWidth * scale));
        var center = pixels / 2.0;
        var pen = new Pen(brush, stroke) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round, LineJoin = PenLineJoin.Round };
        foreach (var radius in new[] { 9.0, 5.0 })
        {
            var snapped = Math.Max(1, Math.Round(radius * scale - stroke / 2)) + stroke / 2;
            dc.DrawEllipse(null, pen, new Point(center, center), snapped, snapped);
        }

        var dot = Math.Max(stroke / 2 + 0.5, 1.2 * scale + stroke / 2);
        dc.DrawEllipse(brush, null, new Point(center, center), dot, dot);
    }

    private static void DrawBadge(DrawingContext dc, int pixels, string text, Color fill, Color ink)
    {
        var height = Math.Max(8, Math.Round(pixels * 0.56));
        var formatted = new FormattedText(
            text,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.Bold, FontStretches.Normal),
            height - 1,
            new SolidColorBrush(ink),
            1.0);
        var width = Math.Min(pixels, Math.Max(height, Math.Round(formatted.WidthIncludingTrailingWhitespace) + 2));
        var rect = new Rect(pixels - width, pixels - height, width, height);
        var radius = Math.Min(3, height / 2);
        dc.DrawRoundedRectangle(new SolidColorBrush(fill), null, rect, radius, radius);
        dc.DrawText(formatted, new Point(rect.X + (width - formatted.Width) / 2, rect.Y + (height - formatted.Height) / 2));
    }
}
