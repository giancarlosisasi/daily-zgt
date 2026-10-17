using System.Runtime.InteropServices;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using DailyZGT.Platform;
using Microsoft.Win32;

// Throwaway checks for the platform adapters. Each mode prints what it observed.
//   PlatformSpike icons <dir>      render the tray icon at several sizes into <dir>
//   PlatformSpike tray <shotdir>   show the tray icon, click and menu through the real handlers, screenshots into <shotdir>
//   PlatformSpike hotkey           register, press (SendInput), clash, clear, persist
//   PlatformSpike startup          Run key and StartupApproved round trips
//   PlatformSpike anim             flip the animation setting and restore it
//   PlatformSpike single [args]    first run listens for 8 s, a later run forwards its args and exits

static void Log(string line) => Console.WriteLine($"{DateTime.Now:HH:mm:ss.fff} {line}");

var mode = args.Length > 0 ? args[0] : "";
var worker = new Thread(() =>
{
var dispatcher = Dispatcher.CurrentDispatcher;
SynchronizationContext.SetSynchronizationContext(new DispatcherSynchronizationContext(dispatcher));

void RunFor(TimeSpan time)
{
    var timer = new DispatcherTimer(DispatcherPriority.Normal, dispatcher) { Interval = time };
    timer.Tick += (_, _) =>
    {
        timer.Stop();
        dispatcher.InvokeShutdown();
    };
    timer.Start();
    Dispatcher.Run();
}

void After(TimeSpan delay, Action action)
{
    var timer = new DispatcherTimer(DispatcherPriority.Normal, dispatcher) { Interval = delay };
    timer.Tick += (_, _) =>
    {
        timer.Stop();
        action();
    };
    timer.Start();
}

switch (mode)
{
    case "icons":
        Icons.Render(args[1]);
        break;
    case "tray":
        Tray.Run(args[1], Log, RunFor, After);
        break;
    case "hotkey":
        Hotkey.Run(Log, RunFor, After);
        break;
    case "startup":
        Startup.Run(Log);
        break;
    case "anim":
        Anim.Run(Log, RunFor, After);
        break;
    case "single":
        Single.Run(args.Skip(1).ToArray(), Log, RunFor);
        break;
    default:
        Log("unknown mode");
        break;
}
});
worker.SetApartmentState(ApartmentState.STA);
worker.Start();
worker.Join();

static class Native
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern nint FindWindow(string? className, string? name);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(nint hwnd, uint message, nint wParam, nint lParam);

    [DllImport("user32.dll")]
    public static extern bool EndMenu();

    [DllImport("user32.dll")]
    public static extern uint SendInput(uint count, Input[] inputs, int size);

    [DllImport("user32.dll")]
    public static extern int SystemParametersInfo(uint action, uint param, nint value, uint winIni);

    [StructLayout(LayoutKind.Sequential)]
    public struct Input
    {
        public uint Type;
        public Keyboard Ki;
        public long Padding;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Keyboard
    {
        public ushort Vk;
        public ushort Scan;
        public uint Flags;
        public uint Time;
        public nint Extra;
    }

    public static void Press(params ushort[] keys)
    {
        var inputs = new List<Input>();
        foreach (var key in keys)
        {
            inputs.Add(new Input { Type = 1, Ki = new Keyboard { Vk = key } });
        }

        foreach (var key in keys.Reverse())
        {
            inputs.Add(new Input { Type = 1, Ki = new Keyboard { Vk = key, Flags = 2 } });
        }

        SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<Input>());
    }

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    private static int Metric(int index) => GetSystemMetrics(index);

    public static void Screenshot(string path, System.Drawing.Rectangle? area = null)
    {
        SetProcessDPIAware();
        var bounds = area ?? new System.Drawing.Rectangle(Metric(76), Metric(77), Metric(78), Metric(79));
        using var bitmap = new System.Drawing.Bitmap(bounds.Width, bounds.Height);
        using (var graphics = System.Drawing.Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen(bounds.Location, System.Drawing.Point.Empty, bounds.Size);
        }

        bitmap.Save(path, System.Drawing.Imaging.ImageFormat.Png);
    }
}

static class Icons
{
    public static void Render(string dir)
    {
        System.IO.Directory.CreateDirectory(dir);
        int?[] counts = [null, 0, 5, 9, 12];
        foreach (var light in new[] { false, true })
        {
            var sheet = new System.Drawing.Bitmap(counts.Length * 140, 4 * 140);
            using var g = System.Drawing.Graphics.FromImage(sheet);
            g.Clear(light ? System.Drawing.Color.FromArgb(243, 243, 243) : System.Drawing.Color.FromArgb(32, 32, 32));
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
            var row = 0;
            foreach (var px in new[] { 16, 20, 24, 32 })
            {
                for (var col = 0; col < counts.Length; col++)
                {
                    var bitmap = TrayIconRenderer.Render(px, counts[col], light);
                    var scale = 128 / px * 1;
                    var stride = px * 4;
                    var pixels = new byte[stride * px];
                    bitmap.CopyPixels(pixels, stride, 0);
                    using var small = new System.Drawing.Bitmap(px, px, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
                    var data = small.LockBits(new System.Drawing.Rectangle(0, 0, px, px), System.Drawing.Imaging.ImageLockMode.WriteOnly, small.PixelFormat);
                    Marshal.Copy(pixels, 0, data.Scan0, pixels.Length);
                    small.UnlockBits(data);
                    g.DrawImage(small, col * 140 + 6, row * 140 + 6, px * scale, px * scale);
                }

                row++;
            }

            var path = System.IO.Path.Combine(dir, light ? "icons-light.png" : "icons-dark.png");
            sheet.Save(path, System.Drawing.Imaging.ImageFormat.Png);
            Console.WriteLine($"saved {path}");
        }
    }
}

static class Tray
{
    public static void Run(string shotDir, Action<string> log, Action<TimeSpan> runFor, Action<TimeSpan, Action> after)
    {
        System.IO.Directory.CreateDirectory(shotDir);
        using var tray = new WindowsTrayIcon();
        tray.Clicked += (_, _) => log("EVENT Clicked");
        tray.OpenRequested += (_, _) => log("EVENT OpenRequested (menu Abrir)");
        tray.QuitRequested += (_, _) => log("EVENT QuitRequested (menu Salir)");
        tray.Show();
        tray.Update(5, "Daily ZGT · 5\nEscribir el informe");
        log($"rect after show: {tray.GetScreenRect()}");

        after(TimeSpan.FromSeconds(1), () =>
        {
            var rect = tray.GetScreenRect();
            log($"rect: {rect}");
            if (rect is { } r)
            {
                var area = new System.Drawing.Rectangle(r.Left - 150, r.Top - 20, 340, r.Height + 40);
                Native.Screenshot(System.IO.Path.Combine(shotDir, "tray-5.png"), area);
            }
        });
        after(TimeSpan.FromSeconds(2), () =>
        {
            tray.Update(12, "Daily ZGT · 12");
            log($"updated to 12, rect: {tray.GetScreenRect()}");
        });
        after(TimeSpan.FromSeconds(3), () =>
        {
            if (tray.GetScreenRect() is { } r)
            {
                Native.Screenshot(System.IO.Path.Combine(shotDir, "tray-12.png"), new System.Drawing.Rectangle(r.Left - 150, r.Top - 20, 340, r.Height + 40));
            }

            tray.Update(null, "Daily ZGT");
        });
        after(TimeSpan.FromSeconds(4), () =>
        {
            if (tray.GetScreenRect() is { } r)
            {
                Native.Screenshot(System.IO.Path.Combine(shotDir, "tray-none.png"), new System.Drawing.Rectangle(r.Left - 150, r.Top - 20, 340, r.Height + 40));
            }
        });
        after(TimeSpan.FromSeconds(4.5), () =>
        {
            var hwnd = Native.FindWindow(null, "DailyZGT.Tray");
            log($"tray window found: {hwnd != 0}");
            Native.PostMessage(hwnd, 0x8001, 0, 0x400 | (1 << 16));
        });
        after(TimeSpan.FromSeconds(5.5), () =>
        {
            var hwnd = Native.FindWindow(null, "DailyZGT.Tray");
            var r = tray.GetScreenRect()!.Value;
            var anchor = (nint)(((r.Top & 0xFFFF) << 16) | ((r.Left + 8) & 0xFFFF));
            Native.PostMessage(hwnd, 0x8001, anchor, 0x7B | (1 << 16));
        });
        after(TimeSpan.FromSeconds(6.5), () =>
        {
            var r = tray.GetScreenRect()!.Value;
            Native.Screenshot(System.IO.Path.Combine(shotDir, "menu.png"), new System.Drawing.Rectangle(r.Left - 250, r.Top - 200, 500, 260));
            var menu = Native.FindWindow("#32768", null);
            log($"menu window found: {menu != 0}");
            Native.PostMessage(menu, 0x0100, 0x28, 0);
            Native.PostMessage(menu, 0x0100, 0x0D, 0);
        });
        runFor(TimeSpan.FromSeconds(9));
        log($"final rect: {tray.GetScreenRect()}");
    }
}

static class Hotkey
{
    private const ushort F24 = 0x87;

    public static void Run(Action<string> log, Action<TimeSpan> runFor, Action<TimeSpan, Action> after)
    {
        const string subKey = @"Software\DailyZGT-SpikeTest";
        try
        {
            log($"default formats as: {ShortcutFormatter.Format(HotkeyShortcut.Default)}");
            var store = new RegistryShortcutStore(subKey);
            log($"empty store loads default: {store.Load() == HotkeyShortcut.Default}");

            using var first = new WindowsGlobalHotkey(store, disabled: false);
            var presses = 0;
            first.Pressed += (_, _) =>
            {
                presses++;
                log("EVENT Pressed");
            };
            log($"start failure: {first.Start()?.ToString() ?? "none"} active={first.IsActive} current={Format(first.Current)}");

            var combo = new HotkeyShortcut(HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift, F24);
            first.Set(combo);
            log($"set {Format(first.Current)} active={first.IsActive}");
            log($"persisted: {store.Load() == combo}");

            using var second = new WindowsGlobalHotkey(new RegistryShortcutStore(subKey + "2"), disabled: false);
            try
            {
                second.Set(combo);
                log("second Set: no failure (unexpected)");
            }
            catch (HotkeyException error)
            {
                log($"second Set failed as expected: {error.Failure}");
            }

            try
            {
                first.Set(new HotkeyShortcut(HotkeyModifiers.None, 'A'));
            }
            catch (HotkeyException error)
            {
                log($"invalid Set: {error.Failure}, current kept: {Format(first.Current)} active={first.IsActive}");
            }

            after(TimeSpan.FromMilliseconds(300), () => Native.Press(0x11, 0x12, 0x10, F24));
            runFor(TimeSpan.FromSeconds(1.5));
            log($"presses seen: {presses}");

            first.Clear();
            log($"cleared: current={Format(first.Current)} active={first.IsActive} persistedEmpty={store.Load() is null}");

            using var off = new WindowsGlobalHotkey(new RegistryShortcutStore(subKey + "3"), disabled: true);
            log($"disabled start: failure={off.Start()?.ToString() ?? "none"} active={off.IsActive}");

            using var fromEnvironment = new WindowsGlobalHotkey(new RegistryShortcutStore(subKey + "3"));
            fromEnvironment.Set(new HotkeyShortcut(HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift, 0x86));
            log($"{WindowsGlobalHotkey.DisableVariable}={Environment.GetEnvironmentVariable(WindowsGlobalHotkey.DisableVariable) ?? "unset"}: Set F23 combo active={fromEnvironment.IsActive} persisted={new RegistryShortcutStore(subKey + "3").Load() == new HotkeyShortcut(HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift, 0x86)}");
        }
        finally
        {
            foreach (var suffix in new[] { string.Empty, "2", "3" })
            {
                Registry.CurrentUser.DeleteSubKeyTree(subKey + suffix, throwOnMissingSubKey: false);
            }
        }
    }

    private static string Format(HotkeyShortcut? shortcut) => shortcut is { } s ? ShortcutFormatter.Format(s) : "none";
}

static class Startup
{
    public static void Run(Action<string> log)
    {
        const string root = @"Software\DailyZGT-SpikeTest";
        try
        {
            var temp = new RegistryStartupRegistration(root + @"\Run", root + @"\Approved", "Spike", () => @"C:\Spike\App.exe");
            log($"initial: {temp.State}");
            temp.Enable();
            log($"after Enable: {temp.State}");
            using (var approved = Registry.CurrentUser.CreateSubKey(root + @"\Approved"))
            {
                approved.SetValue("Spike", new byte[] { 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, RegistryValueKind.Binary);
            }

            log($"after user disables in Settings: {temp.State}");
            temp.Disable();
            log($"after Disable: {temp.State}");

            var bad = new RegistryStartupRegistration(root + @"\" + new string('x', 300), root + @"\Approved", "Spike", () => @"C:\Spike\App.exe");
            try
            {
                bad.Enable();
                log("bad Enable: no failure (unexpected)");
            }
            catch (StartupException error)
            {
                log($"bad Enable failed as typed StartupException: {error.Message}");
            }

            var real = new RegistryStartupRegistration(valueName: "DailyZGTSpikeTest", exePath: () => Environment.ProcessPath);
            real.Enable();
            using (var run = Registry.CurrentUser.OpenSubKey(RegistryStartupRegistration.RunKeyPath))
            {
                log($"real Run value written: {run?.GetValue("DailyZGTSpikeTest")}");
            }

            log($"real state: {real.State}");
            real.Disable();
            log($"real state after Disable: {real.State}");
            var settings = new WindowsSettingsOpener();
            log($"opened ms-settings:startupapps: {settings.OpenStartupApps()}");
            log($"opened ms-settings:notifications: {settings.OpenNotifications()}");
        }
        finally
        {
            Registry.CurrentUser.DeleteSubKeyTree(root, throwOnMissingSubKey: false);
            using var run = Registry.CurrentUser.OpenSubKey(RegistryStartupRegistration.RunKeyPath, writable: true);
            run?.DeleteValue("DailyZGTSpikeTest", throwOnMissingValue: false);
        }
    }
}

static class Anim
{
    public static void Run(Action<string> log, Action<TimeSpan> runFor, Action<TimeSpan, Action> after)
    {
        using var setting = new WindowsAnimationSetting();
        setting.Changed += (_, _) => log($"EVENT Changed, AnimationsEnabled={setting.AnimationsEnabled}");
        setting.Start();
        var original = setting.AnimationsEnabled;
        log($"initial AnimationsEnabled={original}");
        try
        {
            after(TimeSpan.FromMilliseconds(300), () => Set(!original));
            after(TimeSpan.FromMilliseconds(1200), () => Set(original));
            runFor(TimeSpan.FromSeconds(2.5));
        }
        finally
        {
            Set(original);
        }

        log($"restored AnimationsEnabled={setting.AnimationsEnabled}");
    }

    private static void Set(bool enabled)
    {
        var ok = Native.SystemParametersInfo(0x1043, 0, enabled ? 1 : 0, 0x0003);
        Console.WriteLine($"SPI set {enabled} returned {ok}");
    }
}

static class Single
{
    public static void Run(string[] arguments, Action<string> log, Action<TimeSpan> runFor)
    {
        using var instance = new WindowsSingleInstance();
        log($"IsPrimary={instance.IsPrimary}");
        if (instance.IsPrimary)
        {
            instance.ArgumentsReceived += (_, received) => log($"RECEIVED [{string.Join(" | ", received)}]");
            instance.StartListening();
            runFor(TimeSpan.FromSeconds(8));
            return;
        }

        log($"forwarded={instance.ForwardToPrimary(arguments)}");
    }
}
