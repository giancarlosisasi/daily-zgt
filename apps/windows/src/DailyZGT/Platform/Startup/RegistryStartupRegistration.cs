using System.IO;
using Microsoft.Win32;

namespace DailyZGT.Platform;

public sealed class RegistryStartupRegistration : IStartupRegistration
{
    public const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    public const string ApprovedKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
    public const string DefaultValueName = "DailyZGT";

    private readonly string runKeyPath;
    private readonly string approvedKeyPath;
    private readonly string valueName;
    private readonly Func<string?> exePath;

    public RegistryStartupRegistration(
        string runKeyPath = RunKeyPath,
        string approvedKeyPath = ApprovedKeyPath,
        string valueName = DefaultValueName,
        Func<string?>? exePath = null)
    {
        this.runKeyPath = runKeyPath;
        this.approvedKeyPath = approvedKeyPath;
        this.valueName = valueName;
        this.exePath = exePath ?? InstalledApp.CurrentLaunchPath;
    }

    public StartupState State
    {
        get
        {
            try
            {
                using var run = Registry.CurrentUser.OpenSubKey(runKeyPath);
                if (run?.GetValue(valueName) is not string { Length: > 0 })
                {
                    return StartupState.Off;
                }

                using var approved = Registry.CurrentUser.OpenSubKey(approvedKeyPath);
                return StartupApproved.IsDisabled(approved?.GetValue(valueName) as byte[])
                    ? StartupState.OnButDisabledByUser
                    : StartupState.On;
            }
            catch (Exception error) when (error is System.Security.SecurityException or UnauthorizedAccessException or IOException)
            {
                return StartupState.Off;
            }
        }
    }

    public void Enable()
    {
        var path = exePath() ?? throw new StartupException("The app path is unknown.");
        Write(() =>
        {
            using var run = Registry.CurrentUser.CreateSubKey(runKeyPath);
            run.SetValue(valueName, $"\"{path}\"", RegistryValueKind.String);
        });
    }

    public void Disable() => Write(() =>
    {
        using (var run = Registry.CurrentUser.OpenSubKey(runKeyPath, writable: true))
        {
            run?.DeleteValue(valueName, throwOnMissingValue: false);
        }

        using var approved = Registry.CurrentUser.OpenSubKey(approvedKeyPath, writable: true);
        approved?.DeleteValue(valueName, throwOnMissingValue: false);
    });

    private static void Write(Action work)
    {
        try
        {
            work();
        }
        catch (Exception error) when (error is System.Security.SecurityException or UnauthorizedAccessException or IOException or ArgumentException)
        {
            throw new StartupException("Windows did not accept the change.", error);
        }
    }
}
