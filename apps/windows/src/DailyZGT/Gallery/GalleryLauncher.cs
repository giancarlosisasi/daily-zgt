using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using DailyZGT.Core.Localization;
using DailyZGT.Theme;

namespace DailyZGT.Gallery;

// --gallery opens the style gallery. --gallery-snapshot <path.png> renders it at 2x to a PNG and exits.
// --preview-priorities opens the Priorities views on demo rows. --preview-priorities-snapshot <path.png>
// renders them at 2x to a PNG and exits. --state <name> puts the preview in one situation first, and
// --state all renders every state into the folder given as the path. --readme-snapshots <folder> renders the
// README images (priorities, detail, notes, settings, capture and tray) offscreen. --docs-snapshots <folder>
// renders the website docs images, the README ones and more (`just docs-shots`). --lang es, en or pt picks
// the language; both sets default to en.
internal static class GalleryLauncher
{
    private const string GalleryFlag = "--gallery";
    private const string SnapshotFlag = "--gallery-snapshot";
    private const string PreviewFlag = "--preview-priorities";
    private const string PreviewSnapshotFlag = "--preview-priorities-snapshot";
    private const string StateFlag = "--state";
    private const string ReadmeFlag = "--readme-snapshots";
    private const string DocsFlag = "--docs-snapshots";
    private const string LangFlag = "--lang";
    private const string AllStates = "all";
    private const double Scale = 2;
    private static readonly Thickness Backdrop = new(40, 40, 40, 80);

    public static bool TryRun(Application app, string[] args)
    {
        if (TrySnapshots(app, args, ReadmeFlag, ReadmeShots.Readme)
            || TrySnapshots(app, args, DocsFlag, ReadmeShots.Docs)
            || TryPreview(app, args))
        {
            return true;
        }

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

    private static bool TryPreview(Application app, string[] args)
    {
        var snapshot = Array.IndexOf(args, PreviewSnapshotFlag);
        if (snapshot < 0 && Array.IndexOf(args, PreviewFlag) < 0)
        {
            return false;
        }

        var state = Value(args, StateFlag) ?? "list";
        var lang = Value(args, LangFlag);
        var all = state == AllStates;
        if ((!all && !PriorityPreviewWindow.States.Contains(state))
            || (snapshot >= 0 && snapshot + 1 >= args.Length)
            || (lang is not null && !Enum.TryParse<AppLanguage>(lang, ignoreCase: true, out _)))
        {
            Console.Error.WriteLine(
                $"{PreviewSnapshotFlag} needs a path (a folder with {StateFlag} {AllStates}). {StateFlag} is one of: "
                + $"{string.Join(", ", PriorityPreviewWindow.States)}, {AllStates}. {LangFlag} is es, en or pt.");
            app.Shutdown(2);
            return true;
        }

        if (lang is not null)
        {
            UseLanguage(app, Enum.Parse<AppLanguage>(lang, ignoreCase: true));
        }
        if (snapshot < 0)
        {
            var window = new PriorityPreviewWindow();
            window.Closed += (_, _) => app.Shutdown();
            window.Show();
            window.Apply(state);
            return true;
        }

        Motion.IsReduced = true;
        var path = args[snapshot + 1];
        var shots = all
            ? PriorityPreviewWindow.States.Select(name => (name, Path.Combine(path, $"{UiText.Current.Language.ToString().ToLowerInvariant()}-{name}.png"))).ToList()
            : [(state, path)];
        SnapNext(app, shots, 0);
        return true;
    }

    private static bool TrySnapshots(Application app, string[] args, string flag, IReadOnlyList<string> shots)
    {
        var at = Array.IndexOf(args, flag);
        if (at < 0)
        {
            return false;
        }

        var lang = Value(args, LangFlag) ?? nameof(AppLanguage.En);
        if (at + 1 >= args.Length || !Enum.TryParse<AppLanguage>(lang, ignoreCase: true, out var language))
        {
            Console.Error.WriteLine($"{flag} needs a folder. {LangFlag} is es, en or pt.");
            app.Shutdown(2);
            return true;
        }

        UseLanguage(app, language);
        try
        {
            ReadmeShots.Run(args[at + 1], shots);
            app.Shutdown();
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error);
            app.Shutdown(1);
        }

        return true;
    }

    // The XAML bindings read the catalog from the Texts resource, which App.xaml filled before this ran.
    private static void UseLanguage(Application app, AppLanguage language)
    {
        UiText.Current = Texts.For(language);
        app.Resources["Texts"] = UiText.Current;
    }

    // One window per state, so every state starts from the same demo rows.
    private static void SnapNext(Application app, IReadOnlyList<(string State, string Path)> shots, int index)
    {
        if (index >= shots.Count)
        {
            app.Shutdown();
            return;
        }

        var window = new PriorityPreviewWindow
        {
            ShowActivated = false,
            WindowStartupLocation = WindowStartupLocation.Manual,
            Left = -20000,
            Top = 0,
        };
        window.Show();
        window.Apply(shots[index].State);
        window.Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, () =>
        {
            window.UpdateLayout();
            window.SaveSnapshot(shots[index].Path);
            window.Close();
            SnapNext(app, shots, index + 1);
        });
    }

    private static string? Value(string[] args, string flag)
    {
        var at = Array.IndexOf(args, flag);
        return at >= 0 && at + 1 < args.Length ? args[at + 1] : null;
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
