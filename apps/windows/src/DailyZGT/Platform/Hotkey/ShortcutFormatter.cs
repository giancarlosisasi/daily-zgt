namespace DailyZGT.Platform;

public static class ShortcutFormatter
{
    private static readonly Dictionary<int, string> Names = new()
    {
        [0x08] = "Retroceso",
        [0x09] = "Tab",
        [0x0D] = "Entrar",
        [0x13] = "Pausa",
        [0x14] = "Bloq Mayús",
        [0x1B] = "Esc",
        [0x20] = "Espacio",
        [0x21] = "Re Pág",
        [0x22] = "Av Pág",
        [0x23] = "Fin",
        [0x24] = "Inicio",
        [0x25] = "Izquierda",
        [0x26] = "Arriba",
        [0x27] = "Derecha",
        [0x28] = "Abajo",
        [0x2C] = "Impr Pant",
        [0x2D] = "Insertar",
        [0x2E] = "Supr",
        [0xBA] = ";",
        [0xBB] = "=",
        [0xBC] = ",",
        [0xBD] = "-",
        [0xBE] = ".",
        [0xBF] = "/",
        [0xC0] = "`",
        [0xDB] = "[",
        [0xDC] = "\\",
        [0xDD] = "]",
        [0xDE] = "'",
    };

    public static string Format(HotkeyShortcut shortcut)
    {
        var parts = new List<string>(5);
        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Control))
        {
            parts.Add("Ctrl");
        }

        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Alt))
        {
            parts.Add("Alt");
        }

        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Shift))
        {
            parts.Add("Mayús");
        }

        if (shortcut.Modifiers.HasFlag(HotkeyModifiers.Win))
        {
            parts.Add("Win");
        }

        parts.Add(KeyName(shortcut.VirtualKey));
        return string.Join('+', parts);
    }

    private static string KeyName(int key) => key switch
    {
        >= 'A' and <= 'Z' or >= '0' and <= '9' => ((char)key).ToString(),
        >= 0x60 and <= 0x69 => $"Num {key - 0x60}",
        >= 0x70 and <= 0x87 => $"F{key - 0x6F}",
        _ => Names.TryGetValue(key, out var name) ? name : $"Tecla {key:X2}",
    };
}
