using DailyZGT.Core.App;

namespace DailyZGT.Platform;

// The Windows hotkey as Core's CaptureModel and ShortcutSettings see it. The Core enums mirror the
// Platform ones value for value, so the conversions are casts.
public sealed class CaptureHotkey : ICaptureHotkey
{
    private readonly IGlobalHotkey hotkey;

    public CaptureHotkey(IGlobalHotkey hotkey)
    {
        this.hotkey = hotkey;
        hotkey.Pressed += (_, _) => Pressed?.Invoke(this, EventArgs.Empty);
    }

    public CaptureShortcut? Current => hotkey.Current is { } shortcut ? ToCore(shortcut) : null;

    public event EventHandler? Pressed;

    public ShortcutFailure? Start() => (ShortcutFailure?)hotkey.Start();

    public void Set(CaptureShortcut shortcut)
    {
        try
        {
            hotkey.Set(new HotkeyShortcut((HotkeyModifiers)shortcut.Modifiers, shortcut.VirtualKey));
        }
        catch (HotkeyException error)
        {
            throw new ShortcutChangeException((ShortcutFailure)error.Failure, error.Message, error);
        }
    }

    public void Clear() => hotkey.Clear();

    public static CaptureShortcut ToCore(HotkeyShortcut shortcut) => new((ShortcutModifiers)shortcut.Modifiers, shortcut.VirtualKey);

    public static HotkeyShortcut ToPlatform(CaptureShortcut shortcut) => new((HotkeyModifiers)shortcut.Modifiers, shortcut.VirtualKey);
}
