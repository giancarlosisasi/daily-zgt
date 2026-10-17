namespace DailyZGT.Platform;

public enum HotkeyFailure
{
    InvalidShortcut,
    InUse,
    Unavailable,
}

public sealed class HotkeyException(HotkeyFailure failure, string message, Exception? inner = null)
    : Exception(message, inner)
{
    public HotkeyFailure Failure { get; } = failure;
}

public interface IShortcutStore
{
    HotkeyShortcut? Load();

    void Save(HotkeyShortcut? shortcut);
}

public interface IGlobalHotkey : IDisposable
{
    HotkeyShortcut? Current { get; }

    bool IsActive { get; }

    event EventHandler? Pressed;

    HotkeyFailure? Start();

    void Set(HotkeyShortcut shortcut);

    void Clear();
}
