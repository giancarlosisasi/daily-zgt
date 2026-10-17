using System.Windows;

namespace DailyZGT;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (Gallery.GalleryLauncher.TryRun(this, e.Args))
        {
            return;
        }
    }
}
