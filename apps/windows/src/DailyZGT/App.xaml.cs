using System.Windows;
using DailyZGT.Shell;

namespace DailyZGT;

public partial class App : Application
{
    private AppHost? host;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (Gallery.GalleryLauncher.TryRun(this, e.Args))
        {
            return;
        }

        host = AppHost.Start(this, e.Args);
    }

    // Signing out or shutting down saves the notes like Salir does (F16).
    protected override void OnSessionEnding(SessionEndingCancelEventArgs e)
    {
        host?.Quit();
        base.OnSessionEnding(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        host?.Dispose();
        base.OnExit(e);
    }
}
