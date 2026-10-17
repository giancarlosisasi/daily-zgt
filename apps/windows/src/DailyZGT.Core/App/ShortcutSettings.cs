namespace DailyZGT.Core.App;

// Mirrors DailyZGT.Platform.HotkeyModifiers, value for value, so the adapter casts.
[Flags]
public enum ShortcutModifiers
{
    None = 0,
    Alt = 1,
    Control = 2,
    Shift = 4,
    Win = 8,
}

// F17. Mirrors DailyZGT.Platform.HotkeyShortcut: the modifiers and a Win32 virtual-key code.
public readonly record struct CaptureShortcut(ShortcutModifiers Modifiers, int VirtualKey);

// Mirrors DailyZGT.Platform.HotkeyFailure. InvalidShortcut: no modifier and no function key. InUse: Windows
// or another app holds the keys.
public enum ShortcutFailure { InvalidShortcut, InUse, Unavailable }

public sealed class ShortcutChangeException(ShortcutFailure failure, string message, Exception? inner = null)
    : Exception(message, inner)
{
    public ShortcutFailure Failure { get; } = failure;
}

// The app adapts DailyZGT.Platform.IGlobalHotkey to this. Set throws ShortcutChangeException and keeps the
// previous shortcut.
public interface ICaptureHotkey
{
    CaptureShortcut? Current { get; }

    event EventHandler? Pressed;

    ShortcutFailure? Start();

    void Set(CaptureShortcut shortcut);

    void Clear();
}

public enum ShortcutRecording { Idle, Recording }

// F18. "Atajo global". A click records a new shortcut, Escape stops without a change, the clear button or
// Delete while recording removes it. A rejected shortcut keeps the old one and the field says why.
public sealed class ShortcutSettings(ICaptureHotkey hotkey) : ObservableModel
{
    private CaptureShortcut? _shortcut = hotkey.Current;
    private ShortcutRecording _recording;
    private ShortcutFailure? _failure;

    public CaptureShortcut? Shortcut
    {
        get => _shortcut;
        private set
        {
            if (Set(ref _shortcut, value))
            {
                Raise(nameof(IsSet));
            }
        }
    }

    // False: "Sin atajo: la ventana de captura no se abre desde otras apps."
    public bool IsSet => Shortcut is not null;

    public ShortcutRecording Recording
    {
        get => _recording;
        private set => Set(ref _recording, value);
    }

    public ShortcutFailure? Failure
    {
        get => _failure;
        private set => Set(ref _failure, value);
    }

    // At app start. A shortcut another app holds stays saved but inactive, and the field says so.
    public void Start()
    {
        Failure = hotkey.Start();
        Shortcut = hotkey.Current;
    }

    public void SettingsDidOpen()
    {
        Recording = ShortcutRecording.Idle;
        Shortcut = hotkey.Current;
    }

    public void StartRecording()
    {
        Failure = null;
        Recording = ShortcutRecording.Recording;
    }

    // Escape.
    public void CancelRecording()
    {
        Failure = null;
        Recording = ShortcutRecording.Idle;
    }

    // The keys the person pressed while recording. A rejected shortcut keeps the recording open.
    public void Record(CaptureShortcut shortcut)
    {
        try
        {
            hotkey.Set(shortcut);
        }
        catch (ShortcutChangeException error)
        {
            Failure = error.Failure;
            return;
        }
        Failure = null;
        Recording = ShortcutRecording.Idle;
        Shortcut = hotkey.Current;
    }

    public void Clear()
    {
        hotkey.Clear();
        Failure = null;
        Recording = ShortcutRecording.Idle;
        Shortcut = hotkey.Current;
    }
}
