using System.Windows.Input;

namespace DailyZGT.Platform;

public static class WpfShortcut
{
    public static HotkeyShortcut? From(Key key, ModifierKeys modifiers)
    {
        var shortcut = new HotkeyShortcut(ToModifiers(modifiers), KeyInterop.VirtualKeyFromKey(key));
        return shortcut.IsValid ? shortcut : null;
    }

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
