using System.Windows.Interop;

namespace DailyZGT.Platform.Native;

/// <summary>
/// An invisible window on the calling thread. A message-only window does not get broadcast messages
/// (WM_SETTINGCHANGE, TaskbarCreated), so the settings and tray adapters use a hidden top-level window.
/// </summary>
internal sealed class HiddenWindow : IDisposable
{
    private const nint MessageOnlyParent = -3;
    private readonly HwndSource source;
    private readonly HwndSourceHook hook;

    public HiddenWindow(string name, bool messageOnly, HwndSourceHook hook)
    {
        this.hook = hook;
        source = new HwndSource(new HwndSourceParameters(name)
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0,
            ParentWindow = messageOnly ? MessageOnlyParent : 0,
        });
        source.AddHook(hook);
    }

    public nint Handle => source.Handle;

    public void Dispose()
    {
        source.RemoveHook(hook);
        source.Dispose();
    }
}
