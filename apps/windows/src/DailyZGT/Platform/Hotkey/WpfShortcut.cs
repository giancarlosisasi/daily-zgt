using System.Windows.Input;

namespace DailyZGT.Platform;

public static class WpfShortcut
{
    public static HotkeyShortcut? From(Key key, ModifierKeys modifiers)
    {
        var shortcut = Read(key, modifiers);
        return shortcut.IsValid ? shortcut : null;
    }

    // The keys as pressed, valid or not, so the recorder can say why a shortcut was refused.
    public static HotkeyShortcut Read(Key key, ModifierKeys modifiers) =>
        new(ToModifiers(modifiers), KeyInterop.VirtualKeyFromKey(key));

    public static bool IsModifier(Key key) =>
        key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt or Key.LeftShift or Key.RightShift
            or Key.LWin or Key.RWin;

    private static HotkeyModifiers ToModifiers(ModifierKeys keys)
    {
        var result = HotkeyModifiers.None;
        if (keys.HasFlag(ModifierKeys.Control))
        {
            result |= HotkeyModifiers.Control;
        }

        if (keys.HasFlag(ModifierKeys.Alt))
        {
            result |= HotkeyModifiers.Alt;
        }

        if (keys.HasFlag(ModifierKeys.Shift))
        {
            result |= HotkeyModifiers.Shift;
        }

        if (keys.HasFlag(ModifierKeys.Windows))
        {
            result |= HotkeyModifiers.Win;
        }

        return result;
    }
}
