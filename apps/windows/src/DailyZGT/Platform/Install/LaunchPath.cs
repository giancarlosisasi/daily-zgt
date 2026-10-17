using System.IO;

namespace DailyZGT.Platform;

public static class LaunchPath
{
    // Velopack runs the app from <root>\current and keeps a launcher named after the product at <root>.
    // The launcher path survives updates, so the Run key points at it. Outside an install (dotnet run,
    // tests) the process path stays.
    public static string? Resolve(string? processPath, string? installRoot, string productName, Func<string, bool> fileExists)
    {
        if (processPath is null || installRoot is null)
        {
            return processPath;
        }

        var launcher = Path.Combine(installRoot, productName + ".exe");
        return fileExists(launcher) ? launcher : processPath;
    }
}
