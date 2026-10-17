using System.Globalization;
using System.Windows.Data;

namespace DailyZGT.Theme;

// Multiplies a double by the ConverterParameter. The switch uses it to turn a 0 to 1 position into points.
public sealed class ScaleConverter : IValueConverter
{
    public static readonly ScaleConverter Instance = new();

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => (double)value * System.Convert.ToDouble(parameter, CultureInfo.InvariantCulture);

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
