using System.Runtime.InteropServices;
using DailyZGT.Platform.Native;

namespace DailyZGT.Platform;

public sealed class WindowsGlobalHotkey : IGlobalHotkey
{
    public const string DisableVariable = "DAILYZGT_NO_HOTKEY";

    private const int HotkeyId = 1;

    private readonly IShortcutStore store;
    private readonly bool disabled;
    private HiddenWindow? window;
    private HotkeyShortcut? current;
    private bool registered;

    public WindowsGlobalHotkey(IShortcutStore? store = null, bool? disabled = null)
    {
        this.store = store ?? new RegistryShortcutStore();
        this.disabled = disabled ?? Environment.GetEnvironmentVariable(DisableVariable) == "1";
    }

    public event EventHandler? Pressed;

    public HotkeyShortcut? Current => current;

    public bool IsActive => registered;

    public HotkeyFailure? Start()
    {
        current = store.Load();
        if (disabled || current is not { } shortcut)
        {
            return null;
        }

        window ??= new HiddenWindow("DailyZGT.Hotkey", messageOnly: true, OnMessage);
        return TryRegister(shortcut);
    }

    public void Set(HotkeyShortcut shortcut)
    {
        if (!shortcut.IsValid)
        {
            throw new HotkeyException(HotkeyFailure.InvalidShortcut, "The shortcut needs a modifier key or a function key.");
        }

        if (disabled)
        {
            current = shortcut;
            return;
        }

        window ??= new HiddenWindow("DailyZGT.Hotkey", messageOnly: true, OnMessage);
        var previous = current;
        Unregister();
        if (TryRegister(shortcut) is { } failure)
        {
            if (previous is { } restore)
            {
                TryRegister(restore);
            }

            current = previous;
            throw new HotkeyException(failure, failure == HotkeyFailure.InUse
                ? "Another app or Windows already uses these keys."
                : "Windows did not accept the shortcut.");
        }

        store.Save(shortcut);
    }

    public void Clear()
    {
        Unregister();
        current = null;
        if (!disabled)
        {
            store.Save(null);
        }
    }

    public void Dispose()
    {
        Unregister();
        window?.Dispose();
        window = null;
    }

    private HotkeyFailure? TryRegister(HotkeyShortcut shortcut)
    {
        current = shortcut;
        var modifiers = (uint)shortcut.Modifiers | Win32.MOD_NOREPEAT;
        if (Win32.RegisterHotKey(window!.Handle, HotkeyId, modifiers, (uint)shortcut.VirtualKey))
        {
            registered = true;
            return null;
        }

        var error = Marshal.GetLastPInvokeError();
        return error == Win32.ERROR_HOTKEY_ALREADY_REGISTERED ? HotkeyFailure.InUse : HotkeyFailure.Unavailable;
    }

    private void Unregister()
    {
        if (registered && window is not null)
        {
            Win32.UnregisterHotKey(window.Handle, HotkeyId);
        }

        registered = false;
    }

    private nint OnMessage(nint hwnd, int message, nint wParam, nint lParam, ref bool handled)
    {
        if (message == Win32.WM_HOTKEY && wParam == HotkeyId)
        {
            handled = true;
            Pressed?.Invoke(this, EventArgs.Empty);
        }

        return 0;
    }
}
