using Microsoft.Win32;

namespace DailyZGT.Platform;

public sealed class RegistryShortcutStore(string subKey = RegistryShortcutStore.DefaultSubKey, string valueName = "CaptureShortcut")
    : IShortcutStore
{
    public const string DefaultSubKey = @"Software\DailyZGT";

    public HotkeyShortcut? Load()
    {
        using var key = Registry.CurrentUser.OpenSubKey(subKey);
        return key?.GetValue(valueName) switch
        {
            string { Length: 0 } => null,
            string text when HotkeyShortcut.TryParse(text, out var shortcut) => shortcut,
            _ => HotkeyShortcut.Default,
        };
    }

    public void Save(HotkeyShortcut? shortcut)
    {
        using var key = Registry.CurrentUser.CreateSubKey(subKey);
        key.SetValue(valueName, shortcut?.Serialize() ?? string.Empty, RegistryValueKind.String);
    }
}
