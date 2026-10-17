using CommunityToolkit.WinUI.Notifications;
using DailyZGT.Platform;
using Velopack;

namespace DailyZGT;

public static class Program
{
    // Velopack runs install, update and uninstall hooks from this exe and exits when it handled one, so it
    // goes before the single-instance check and before WPF shows anything.
    [STAThread]
    public static void Main()
    {
        VelopackApp.Build()
            .OnBeforeUninstallFastCallback(_ => new UninstallCleanup(
                new RegistryStartupRegistration(),
                RegistryShortcutStore.DefaultSubKey,
                ToastNotificationManagerCompat.Uninstall).Run())
            .Run();

        var app = new App();
        app.InitializeComponent();
        app.Run();
    }
}
