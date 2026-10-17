using System.IO;
using System.Reflection;
using Velopack.Locators;

namespace DailyZGT.Platform;

public static class InstalledApp
{
    public static string? CurrentLaunchPath() =>
        LaunchPath.Resolve(Environment.ProcessPath, InstallRoot(), ProductName(), File.Exists);

    // The Product property of the csproj. The pack script gives the same value to vpk as the pack title,
    // which names the launcher.
    private static string ProductName() =>
        Assembly.GetEntryAssembly()?.GetCustomAttribute<AssemblyProductAttribute>()?.Product ?? "Daily ZGT";

    private static string? InstallRoot()
    {
        try
        {
            return VelopackLocator.IsCurrentSet && VelopackLocator.Current.CurrentlyInstalledVersion is not null
                ? VelopackLocator.Current.RootAppDir
                : null;
        }
        catch (Exception)
        {
            return null;
        }
    }
}
