using System.Reflection;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;

namespace DailyZGT.Theme;

// Turns every token in TeclaTokens into a XAML resource, so a token that tecla.json adds shows up
// here with no edit. Keys (G is the token group, N the token name, as the generated class spells them):
//   Color.G.N, Brush.G.N       a Color and a frozen SolidColorBrush, for Colors, Palette, Panel and the color tokens of Key
//   Radius.N, RadiusPx.N       a CornerRadius and a double
//   Space.N, Size.N, Key.N     a double
//   Thickness.N                a Thickness for each Size token (Thickness.CheckboxLine)
//   Font.N                     a FontFamily (Display, Text, Mono)
//   FontSize.N, FontWeight.N, LineHeight.N      one text style: size, weight, line height in points
//   Duration.N, KeyTime.N      a Duration and a KeyTime from the duration tokens
//   Easing.N                   a KeySpline
//   Effect.N.I                 a DropShadowEffect for layer I of shadow N when the layer blurs
//   ShadowOffset.N.I           the y offset and Brush.Shadow.N.I the color of layer I of shadow N when it does not blur
//   Radius.InputSegment        the radius of a segment inside a form field (Radius.Input minus the 2 pt track padding)
public sealed class TeclaTokenResources : ResourceDictionary
{
    private const double SegmentTrackPadding = 2;

    private static readonly IReadOnlyList<KeyValuePair<string, object>> Entries = Build();

    public TeclaTokenResources()
    {
        foreach (var (key, value) in Entries)
        {
            Add(key, value);
        }
    }

    private static List<KeyValuePair<string, object>> Build()
    {
        var entries = new List<KeyValuePair<string, object>>();

        void Add(string key, object value)
        {
            if (value is Freezable { CanFreeze: true } freezable)
            {
                freezable.Freeze();
            }

            entries.Add(new(key, value));
        }

        foreach (var group in typeof(TeclaTokens).GetNestedTypes(BindingFlags.Public))
        {
            foreach (var field in group.GetFields(BindingFlags.Public | BindingFlags.Static))
            {
                var name = field.Name;
                var value = field.GetValue(null);
                var path = group.Name + "." + name;
                switch (value)
                {
                    case Color color:
                        Add("Color." + path, color);
                        Add("Brush." + path, new SolidColorBrush(color));
                        break;
                    case double number when group.Name == "Radius":
                        Add("Radius." + name, new CornerRadius(number));
                        Add("RadiusPx." + name, number);
                        break;
                    case double number:
                        Add(path, number);
                        if (group.Name == "Size")
                        {
                            Add("Thickness." + name, new Thickness(number));
                        }

                        break;
                    case TeclaTextStyle style:
                        Add("FontSize." + name, style.Size);
                        Add("FontWeight." + name, style.FontWeight);
                        Add("LineHeight." + name, style.LineHeightPixels);
                        break;
                    case TeclaFontFamily family when name != "All":
                        Add("Font." + name, family.Font);
                        break;
                    case TimeSpan duration:
                        Add("Duration." + name, new Duration(duration));
                        Add("KeyTime." + name, KeyTime.FromTimeSpan(duration));
                        break;
                    case TeclaEasing easing:
                        Add("Easing." + name, easing.Spline);
                        break;
                    case TeclaShadow[] layers:
                        for (var index = 0; index < layers.Length; index++)
                        {
                            AddShadow(Add, name + "." + index, layers[index]);
                        }

                        break;
                }
            }
        }

        var inner = TeclaTokens.Radius.Input - SegmentTrackPadding;
        Add("Radius.InputSegment", new CornerRadius(inner));
        Add("RadiusPx.InputSegment", inner);
        return entries;
    }

    private static void AddShadow(Action<string, object> add, string name, TeclaShadow shadow)
    {
        if (shadow.Blur > 0)
        {
            var color = Color.FromRgb(shadow.Color.R, shadow.Color.G, shadow.Color.B);
            add("Effect." + name, new DropShadowEffect
            {
                Color = color,
                Opacity = shadow.Color.A / 255.0,
                ShadowDepth = shadow.Y,
                Direction = 270,
                BlurRadius = shadow.Blur,
            });
        }
        else
        {
            add("ShadowOffset." + name, shadow.Y);
            add("Brush.Shadow." + name, new SolidColorBrush(shadow.Color));
        }
    }
}
