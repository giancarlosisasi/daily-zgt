using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using DailyZGT.Theme;

namespace DailyZGT.Gallery;

// --gallery opens the style gallery. --gallery-snapshot <path.png> renders it at 2x to a PNG and exits.
internal static class GalleryLauncher
{
    private const string GalleryFlag = "--gallery";
    private const string SnapshotFlag = "--gallery-snapshot";
    private const double Scale = 2;
    private static readonly Thickness Backdrop = new(40, 40, 40, 80);

    public static bool TryRun(Application app, string[] args)
    {
        var snapshot = Array.IndexOf(args, SnapshotFlag);
        if (snapshot >= 0)
        {
            if (snapshot + 1 >= args.Length)
            {
                Console.Error.WriteLine($"{SnapshotFlag} needs a path.");
                app.Shutdown(2);
                return true;
            }

            Render(args[snapshot + 1]);
            app.Shutdown();
            return true;
        }

        if (Array.IndexOf(args, GalleryFlag) >= 0)
        {
            var window = new GalleryWindow();
            window.Closed += (_, _) => app.Shutdown();
            window.Show();
            return true;
        }

        return false;
    }

    private static void Render(string path)
    {
        var stage = new Border
        {
            Background = new SolidColorBrush(TeclaTokens.Colors.Ground),
            Padding = Backdrop,
            Child = new GalleryView(),
            UseLayoutRounding = true,
        };
        stage.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        stage.Arrange(new Rect(stage.DesiredSize));
        stage.UpdateLayout();
        stage.Dispatcher.Invoke(DispatcherPriority.Loaded, () => stage.UpdateLayout());

        var width = (int)Math.Ceiling(stage.ActualWidth * Scale);
        var height = (int)Math.Ceiling(stage.ActualHeight * Scale);
        var bitmap = new RenderTargetBitmap(width, height, 96 * Scale, 96 * Scale, PixelFormats.Pbgra32);
        bitmap.Render(stage);

        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        using var file = File.Create(path);
        encoder.Save(file);
    }
}
