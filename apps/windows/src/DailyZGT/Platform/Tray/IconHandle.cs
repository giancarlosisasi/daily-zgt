using System.Runtime.InteropServices;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DailyZGT.Platform.Native;

namespace DailyZGT.Platform;

internal sealed class IconHandle : IDisposable
{
    private IconHandle(nint handle) => Handle = handle;

    public nint Handle { get; private set; }

    public static IconHandle From(BitmapSource source)
    {
        var straight = new FormatConvertedBitmap(source, PixelFormats.Bgra32, null, 0);
        var width = straight.PixelWidth;
        var height = straight.PixelHeight;
        var pixels = new byte[width * height * 4];
        straight.CopyPixels(pixels, width * 4, 0);

        var header = new Win32.BitmapInfoHeader
        {
            biSize = (uint)Marshal.SizeOf<Win32.BitmapInfoHeader>(),
            biWidth = width,
            biHeight = -height,
            biPlanes = 1,
            biBitCount = 32,
        };
        var color = Win32.CreateDIBSection(0, ref header, 0, out var bits, 0, 0);
        if (color == 0)
        {
            throw new InvalidOperationException("Windows could not create the icon bitmap.");
        }

        Marshal.Copy(pixels, 0, bits, pixels.Length);
        var mask = Win32.CreateBitmap(width, height, 1, 1, 0);
        try
        {
            var info = new Win32.IconInfo { fIcon = true, hbmColor = color, hbmMask = mask };
            var icon = Win32.CreateIconIndirect(ref info);
            return icon == 0
                ? throw new InvalidOperationException("Windows could not create the icon.")
                : new IconHandle(icon);
        }
        finally
        {
            Win32.DeleteObject(color);
            Win32.DeleteObject(mask);
        }
    }

    public void Dispose()
    {
        if (Handle != 0)
        {
            Win32.DestroyIcon(Handle);
            Handle = 0;
        }
    }
}
