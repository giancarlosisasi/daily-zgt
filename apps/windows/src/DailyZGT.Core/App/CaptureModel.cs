using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F17. The line under the field.
public enum CaptureNotice { None, TodayLimit, SaveFailed }

public enum CaptureCloseReason { Added, Escape, Shortcut, LostFocus }

public static class CaptureCloseReasons
{
    // F17. Enter, Escape and the shortcut give the focus back to the app the person was in. A click
    // elsewhere or a switch to another app does not.
    public static bool RestoresFocus(this CaptureCloseReason reason) => reason != CaptureCloseReason.LostFocus;
}

// F17. The capture window: it adds to Hoy with level Media and no due date. Enter adds and closes. The limit
// and a save error keep it open with the text and a notice. Every open starts empty.
public sealed class CaptureModel(AppStore store) : ObservableModel, IDisposable
{
    private ICaptureHotkey? _hotkey;
    private bool _isOpen;
    private string _title = "";
    private CaptureNotice _notice;

    public bool IsOpen
    {
        get => _isOpen;
        private set => Set(ref _isOpen, value);
    }

    public string Title
    {
        get => _title;
        set => Set(ref _title, value);
    }

    public CaptureNotice Notice
    {
        get => _notice;
        private set => Set(ref _notice, value);
    }

    public event EventHandler? Opened;

    public event EventHandler<CaptureCloseReason>? Closed;

    // The global shortcut opens the window, and closes it when it is open.
    public void Attach(ICaptureHotkey hotkey)
    {
        Detach();
        _hotkey = hotkey;
        hotkey.Pressed += OnShortcut;
    }

    public void Open()
    {
        if (IsOpen)
        {
            return;
        }
        Title = "";
        Notice = CaptureNotice.None;
        IsOpen = true;
        Opened?.Invoke(this, EventArgs.Empty);
    }

    public void Toggle()
    {
        if (IsOpen)
        {
            Close(CaptureCloseReason.Shortcut);
        }
        else
        {
            Open();
        }
    }

    // Enter.
    public void Submit()
    {
        AddOutcome outcome;
        try
        {
            outcome = store.CapturePriority(Title);
        }
        catch (StoreException)
        {
            Notice = CaptureNotice.SaveFailed;
            return;
        }
        switch (outcome)
        {
            case AddOutcome.Added:
                Title = "";
                Notice = CaptureNotice.None;
                Close(CaptureCloseReason.Added);
                break;
            case AddOutcome.BlockedByTodayLimit:
                Notice = CaptureNotice.TodayLimit;
                break;
        }
    }

    // Escape.
    public void Cancel() => Close(CaptureCloseReason.Escape);

    // A click outside the window or a switch to another app.
    public void Dismiss() => Close(CaptureCloseReason.LostFocus);

    public void Dispose() => Detach();

    private void Close(CaptureCloseReason reason)
    {
        if (!IsOpen)
        {
            return;
        }
        IsOpen = false;
        Closed?.Invoke(this, reason);
    }

    private void OnShortcut(object? sender, EventArgs e) => Toggle();

    private void Detach()
    {
        if (_hotkey is not null)
        {
            _hotkey.Pressed -= OnShortcut;
            _hotkey = null;
        }
    }
}
