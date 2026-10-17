using DailyZGT.Platform.Native;

namespace DailyZGT.Platform;

public sealed class WindowsAnimationSetting : IAnimationSetting
{
    private HiddenWindow? window;
    private bool enabled = Read();

    public bool AnimationsEnabled => enabled;

    public event EventHandler? Changed;

    public void Start()
    {
        enabled = Read();
        window ??= new HiddenWindow("DailyZGT.Motion", messageOnly: false, OnMessage);
    }

    public void Dispose()
    {
        window?.Dispose();
        window = null;
    }

    private static bool Read()
    {
        var value = 1;
        return !Win32.SystemParametersInfoW(Win32.SPI_GETCLIENTAREAANIMATION, 0, ref value, 0) || value != 0;
    }

    private nint OnMessage(nint hwnd, int message, nint wParam, nint lParam, ref bool handled)
    {
        if (message == Win32.WM_SETTINGCHANGE)
        {
            var now = Read();
            if (now != enabled)
            {
                enabled = now;
                Changed?.Invoke(this, EventArgs.Empty);
            }
        }

        return 0;
    }
}
