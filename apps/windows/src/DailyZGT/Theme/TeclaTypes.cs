using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace DailyZGT.Theme;

public sealed record TeclaFontFamily(string Family, int[] Weights, double? Width, string File)
{
    public FontFamily Font => TeclaFonts.Family(Family);
}

public sealed record TeclaTextStyle(double Size, double LineHeight, double TrackingEm, int Weight, TeclaFontFamily Family)
{
    public FontWeight FontWeight => FontWeight.FromOpenTypeWeight(Weight);

    public double LineHeightPixels => Size * LineHeight;
}

public sealed record TeclaShadow(double X, double Y, double Blur, Color Color);

public sealed record TeclaEasing(double X1, double Y1, double X2, double Y2, TimeSpan Duration)
{
    public KeySpline Spline => new(X1, Y1, X2, Y2);
}

public sealed record TeclaSpring(double Response, double DampingFraction);

public static class TeclaFonts
{
    private const string Folder = "pack://application:,,,/Assets/Fonts/";

    public static FontFamily Family(string name) => new(new Uri(Folder), "./#" + name);
}
