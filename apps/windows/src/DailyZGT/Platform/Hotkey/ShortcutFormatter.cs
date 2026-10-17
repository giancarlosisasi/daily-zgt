using DailyZGT.Core.Localization;

namespace DailyZGT.Platform;

public static class ShortcutFormatter
{
    public static string Format(HotkeyShortcut shortcut, Texts texts)
    {
        var parts = new List<string>(5);
        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Control))
        {
            parts.Add(texts.KeyCtrl);
        }

        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Alt))
        {
            parts.Add(texts.KeyAlt);
        }

        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Shift))
        {
            parts.Add(texts.KeyShift);
        }

        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Win))
        {
            parts.Add(texts.KeyWin);
        }

        parts.Add(KeyName(shortcut.VirtualKey, texts));
        return string.Join('+', parts);
    }

    private static string KeyName(int key, Texts texts) => key switch
    {
        >= 'A' and <= 'Z' or >= '0' and <= '9' => ((char)key).ToString(),
        >= 0x60 and <= 0x69 => texts.KeyNumpad(key - 0x60),
        >= 0x70 and <= 0x87 => $"F{key - 0x6F}",
        0x08 => texts.KeyBackspace,
        0x09 => texts.KeyTab,
        0x0D => texts.KeyEnter,
        0x13 => texts.KeyPause,
        0x14 => texts.KeyCapsLock,
        0x1B => texts.KeyEscape,
        0x20 => texts.KeySpace,
        0x21 => texts.KeyPageUp,
        0x22 => texts.KeyPageDown,
        0x23 => texts.KeyEnd,
        0x24 => texts.KeyHome,
        0x25 => texts.KeyLeft,
        0x26 => texts.KeyUp,
        0x27 => texts.KeyRight,
        0x28 => texts.KeyDown,
        0x2C => texts.KeyPrintScreen,
        0x2D => texts.KeyInsert,
        0x2E => texts.KeyDelete,
        0xBA => ";",
        0xBB => "=",
        0xBC => ",",
        0xBD => "-",
        0xBE => ".",
        0xBF => "/",
        0xC0 => "`",
        0xDB => "[",
        0xDC => "\\",
        0xDD => "]",
        0xDE => "'",
        _ => texts.KeyOther(key),
    };
}
