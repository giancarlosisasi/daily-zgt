using Microsoft.Win32;

namespace DailyZGT.Platform.Tests;

public class InstallTests
{
    private const string Root = @"C:\Users\x\AppData\Local\DailyZGT.Windows";
    private const string Current = Root + @"\current\DailyZGT.exe";
    private const string Launcher = Root + @"\Daily ZGT.exe";

    [Fact]
    public void RunKeyPointsAtTheLauncherWhenInstalled()
    {
        Assert.Equal(Launcher, LaunchPath.Resolve(Current, Root, "Daily ZGT", path => path == Launcher));
    }

    [Fact]
    public void RunKeyKeepsTheProcessPathWhenNotInstalled()
    {
        const string debug = @"D:\src\bin\Debug\DailyZGT.exe";
        Assert.Equal(debug, LaunchPath.Resolve(debug, null, "Daily ZGT", _ => true));
    }

    [Fact]
    public void RunKeyKeepsTheProcessPathWhenTheLauncherIsMissing()
    {
        Assert.Equal(Current, LaunchPath.Resolve(Current, Root, "Daily ZGT", _ => false));
    }

    [Fact]
    public void CleanupRemovesTheStartupValueTheToastRegistrationAndTheSettingsKey()
    {
        var key = @"Software\DailyZGT.Tests." + Guid.NewGuid().ToString("N");
        using (var created = Registry.CurrentUser.CreateSubKey(key))
        {
            created.SetValue("CaptureShortcut", "Ctrl+Alt+Shift+P");
        }

        var startup = new FakeStartup();
        var toastRemoved = false;

        new UninstallCleanup(startup, key, () => toastRemoved = true).Run();

        Assert.True(startup.Disabled);
        Assert.True(toastRemoved);
        Assert.Null(Registry.CurrentUser.OpenSubKey(key));
    }

    [Fact]
    public void CleanupRunsEveryStepWhenOneFails()
    {
        var key = @"Software\DailyZGT.Tests." + Guid.NewGuid().ToString("N");
        Registry.CurrentUser.CreateSubKey(key).Dispose();
        var startup = new FakeStartup { Fails = true };
        var toastRemoved = false;

        new UninstallCleanup(startup, key, () => toastRemoved = true).Run();

        Assert.True(toastRemoved);
        Assert.Null(Registry.CurrentUser.OpenSubKey(key));
    }

    [Fact]
    public void CleanupSucceedsWhenNothingWasRegistered()
    {
        var key = @"Software\DailyZGT.Tests." + Guid.NewGuid().ToString("N");

        new UninstallCleanup(new FakeStartup(), key, () => { }).Run();

        Assert.Null(Registry.CurrentUser.OpenSubKey(key));
    }

    private sealed class FakeStartup : IStartupRegistration
    {
        public bool Disabled { get; private set; }

        public bool Fails { get; init; }

        public StartupState State => StartupState.Off;

        public void Enable()
        {
        }

        public void Disable()
        {
            if (Fails)
            {
                throw new StartupException("no");
            }

            Disabled = true;
        }
    }
}
