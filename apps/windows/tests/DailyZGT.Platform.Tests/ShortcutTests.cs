using DailyZGT.Platform;

namespace DailyZGT.Platform.Tests;

public class ShortcutTests
{
    private const HotkeyModifiers CtrlAlt = HotkeyModifiers.Control | HotkeyModifiers.Alt;

    [Fact]
    public void DefaultShortcutIsCtrlAltShiftP()
    {
        Assert.Equal("Ctrl+Alt+Mayús+P", ShortcutFormatter.Format(HotkeyShortcut.Default));
    }

    [Theory]
    [InlineData(HotkeyModifiers.Control, 0x4B, "Ctrl+K")]
    [InlineData(CtrlAlt, 0x70, "Ctrl+Alt+F1")]
    [InlineData(HotkeyModifiers.None, 0x87, "F24")]
    [InlineData(HotkeyModifiers.Win | HotkeyModifiers.Shift, 0x20, "Mayús+Win+Espacio")]
    [InlineData(HotkeyModifiers.Alt, 0x2E, "Alt+Supr")]
    [InlineData(HotkeyModifiers.Control, 0x37, "Ctrl+7")]
    [InlineData(HotkeyModifiers.Control, 0xBC, "Ctrl+,")]
    public void FormatsInSpanishWindowsStyle(HotkeyModifiers modifiers, int key, string expected)
    {
        Assert.Equal(expected, ShortcutFormatter.Format(new HotkeyShortcut(modifiers, key)));
    }

    [Theory]
    [InlineData(HotkeyModifiers.None, 0x41, false)]
    [InlineData(HotkeyModifiers.Shift, 0x41, true)]
    [InlineData(HotkeyModifiers.None, 0x7B, true)]
    [InlineData(HotkeyModifiers.Control, 0x11, false)]
    [InlineData(HotkeyModifiers.Control, 0, false)]
    [InlineData(HotkeyModifiers.Control, 255, false)]
    public void NeedsAModifierOrAFunctionKey(HotkeyModifiers modifiers, int key, bool valid)
    {
        Assert.Equal(valid, new HotkeyShortcut(modifiers, key).IsValid);
    }

    [Fact]
    public void RoundTripsThroughText()
    {
        var shortcut = new HotkeyShortcut(CtrlAlt | HotkeyModifiers.Win, 0x51);

        Assert.True(HotkeyShortcut.TryParse(shortcut.Serialize(), out var parsed));
        Assert.Equal(shortcut, parsed);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("7")]
    [InlineData("7,x")]
    [InlineData("99,80")]
    [InlineData("0,80")]
    [InlineData("7,80,1")]
    public void RejectsBrokenText(string? text)
    {
        Assert.False(HotkeyShortcut.TryParse(text, out _));
    }
}
