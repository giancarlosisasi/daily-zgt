using System.ComponentModel;
using System.Diagnostics;

namespace DailyZGT.Platform;

public sealed class WindowsSettingsOpener : ISystemSettings
{
    public const string StartupAppsUri = "ms-settings:startupapps";
    public const string NotificationsUri = "ms-settings:notifications";

    public bool OpenStartupApps() => Open(StartupAppsUri);

    public bool OpenNotifications() => Open(NotificationsUri);

    private static bool Open(string uri)
    {
        try
        {
            using var process = Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
            return true;
        }
        catch (Exception error) when (error is Win32Exception or InvalidOperationException)
        {
            return false;
        }
    }
}
