using Microsoft.Win32;

namespace DailyZGT.Platform;

// What the uninstaller takes back from the system. It never touches the data folder: the database is the
// person's, and the installer removes only its own folder.
public sealed class UninstallCleanup(IStartupRegistration startup, string settingsKey, Action removeToastRegistration)
{
    public void Run()
    {
        Attempt(startup.Disable);
        Attempt(removeToastRegistration);
        Attempt(() => Registry.CurrentUser.DeleteSubKeyTree(settingsKey, throwOnMissingSubKey: false));
    }

    // The uninstall hook has 30 seconds and the folder goes away anyway, so one failed step must not skip the rest.
    private static void Attempt(Action step)
    {
        try
        {
            step();
        }
        catch (Exception)
        {
        }
    }
}
