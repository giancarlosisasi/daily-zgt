namespace DailyZGT.Platform;

[Flags]
public enum HotkeyModifiers
{
    None = 0,
    Alt = 1,
    Control = 2,
    Shift = 4,
    Win = 8,
}

public readonly record struct HotkeyShortcut(HotkeyModifiers Modifiers, int VirtualKey)
{
    private const int FirstFunctionKey = 0x70;
    private const int LastFunctionKey = 0x87;

    public static HotkeyShortcut Default { get; } =
        new(HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift, 'P');

    public bool IsValid =>
        VirtualKey is > 0 and < 255
        && !IsModifierKey(VirtualKey)
        && (Modifiers != HotkeyModifiers.None || IsFunctionKey(VirtualKey));

    public string Serialize() => $"{(int)Modifiers},{VirtualKey}";

    public static bool TryParse(string? text, out HotkeyShortcut shortcut)
    {
        shortcut = default;
        var parts = text?.Split(',');
        if (parts is not { Length: 2 }
            || !int.TryParse(parts[0], out var modifiers)
            || !int.TryParse(parts[1], out var key)
            || modifiers is < 0 or > 15)
        {
            return false;
        }

        var parsed = new HotkeyShortcut((HotkeyModifiers)modifiers, key);
        if (!parsed.IsValid)
        {
            return false;
        }

        shortcut = parsed;
        return true;
    }

    internal static bool IsFunctionKey(int key) => key is >= FirstFunctionKey and <= LastFunctionKey;

    private static bool IsModifierKey(int key) => key is 0x10 or 0x11 or 0x12 or 0x5B or 0x5C or (>= 0xA0 and <= 0xA5);
}
