using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Automation;

namespace DailyZGT.UiTests;

// One run of the built DailyZGT.exe on a fresh data folder, driven through UI Automation and real input.
// The session only looks at the processes it started from that exe with that data folder, so a Daily ZGT the
// person runs, or another worktree's build, is never touched. Dispose quits the app and deletes the folder.
public sealed class AppSession : IDisposable
{
    public static readonly TimeSpan Patience = TimeSpan.FromSeconds(15);

    private readonly List<Process> _started = [];
    private readonly string _language;

    private AppSession(string language)
    {
        _language = language;
        DataDir = Path.Combine(Path.GetTempPath(), "dailyzgt-ui-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(DataDir);
    }

    // DAILYZGT_EXE points at another build; by default the exe of the same configuration as these tests.
    public static string ExePath { get; } = Environment.GetEnvironmentVariable("DAILYZGT_EXE") is { Length: > 0 } exe
        ? Path.GetFullPath(exe)
        : DefaultExePath();

    public string DataDir { get; }

    public static AppSession Start(string language = "es")
    {
        var session = new AppSession(language);
        session.Launch("--show-panel");
        session.Wait("PanelWindow");
        return session;
    }

    // A launch while the app runs hands its arguments to the running copy and exits.
    public void Launch(params string[] args)
    {
        if (!File.Exists(ExePath))
        {
            throw new FileNotFoundException("Build the app first (just win-build), or set DAILYZGT_EXE.", ExePath);
        }

        var info = new ProcessStartInfo(ExePath) { UseShellExecute = false, WorkingDirectory = DataDir };
        foreach (var arg in args)
        {
            info.ArgumentList.Add(arg);
        }

        info.Environment["DAILYZGT_DATA_DIR"] = DataDir;
        info.Environment["DAILYZGT_NO_HOTKEY"] = "1";
        info.Environment["DAILYZGT_LANG"] = _language;
        _started.Add(Process.Start(info) ?? throw new InvalidOperationException("The app did not start."));
    }

    // Salir, then the same data folder again with the panel open.
    public void Restart()
    {
        Quit();
        Launch("--show-panel");
        Wait("PanelWindow");
    }

    public void Quit()
    {
        Invoke("QuitButton");
        Until(() => !Running().Any(), "the app quits");
    }

    public AutomationElement? Find(string id)
    {
        if (id.EndsWith('*'))
        {
            return FindAll(id[..^1]).FirstOrDefault();
        }

        foreach (var window in Windows())
        {
            if (window.Current.AutomationId == id)
            {
                return window;
            }

            var found = window.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.AutomationIdProperty, id));
            if (found is not null && !found.Current.IsOffscreen)
            {
                return found;
            }
        }

        return null;
    }

    // Every shown element whose AutomationId starts with the prefix, in the order of the tree.
    public IReadOnlyList<AutomationElement> FindAll(string prefix) =>
        Windows()
            .SelectMany(window => window.FindAll(TreeScope.Descendants, Condition.TrueCondition).Cast<AutomationElement>())
            .Where(e => e.Current.AutomationId.StartsWith(prefix, StringComparison.Ordinal) && !e.Current.IsOffscreen)
            .ToList();

    public AutomationElement Wait(string id) =>
        Until(() => Find(id), $"{id} shows");

    public void WaitGone(string id) =>
        Until(() => Find(id) is null, $"{id} goes away");

    public string Name(string id) => Wait(id).Current.Name;

    public string Value(string id) => ((ValuePattern)Wait(id).GetCurrentPattern(ValuePattern.Pattern)).Current.Value;

    // The names of the element and of everything inside it, such as the chips of a row.
    public IReadOnlyList<string> Texts(string id) =>
        Wait(id).FindAll(TreeScope.Subtree, Condition.TrueCondition).Cast<AutomationElement>().Select(e => e.Current.Name).ToList();

    // Polls until the value matches, then asserts on the last value seen, so a failure names what the UI showed.
    public void Expect<T>(T expected, Func<T> actual)
    {
        var deadline = DateTime.UtcNow + Patience;
        var last = actual();
        while (!EqualityComparer<T>.Default.Equals(last, expected) && DateTime.UtcNow < deadline)
        {
            Thread.Sleep(150);
            last = actual();
        }

        Assert.Equal(expected, last);
    }

    // Polls until an element inside the given one has the text, such as a chip of a row.
    public void ExpectText(string id, string text)
    {
        var deadline = DateTime.UtcNow + Patience;
        var last = Texts(id);
        while (!last.Contains(text) && DateTime.UtcNow < deadline)
        {
            Thread.Sleep(150);
            last = Texts(id);
        }

        Assert.Contains(text, last);
    }

    public void Click(string id)
    {
        var bounds = Wait(id).Current.BoundingRectangle;
        Native.Click((int)(bounds.Left + bounds.Width / 2), (int)(bounds.Top + bounds.Height / 2));
        Thread.Sleep(120);
    }

    // Invoke for a button, Toggle for a switch, Select for a tab or a level key.
    public void Invoke(string id)
    {
        var element = Wait(id);
        if (element.TryGetCurrentPattern(InvokePattern.Pattern, out var invoke))
        {
            ((InvokePattern)invoke).Invoke();
        }
        else if (element.TryGetCurrentPattern(TogglePattern.Pattern, out var toggle))
        {
            ((TogglePattern)toggle).Toggle();
        }
        else if (element.TryGetCurrentPattern(SelectionItemPattern.Pattern, out var select))
        {
            ((SelectionItemPattern)select).Select();
        }
        else
        {
            throw new InvalidOperationException($"{id} has no invoke, toggle or select pattern.");
        }

        Thread.Sleep(120);
    }

    public void Type(string text)
    {
        Native.Type(text);
        Thread.Sleep(120);
    }

    public void Key(string chord)
    {
        Native.Key(chord);
        Thread.Sleep(120);
    }

    // True when the window that has the focus belongs to this app.
    public bool OwnsForeground()
    {
        var pid = Native.ForegroundProcessId();
        return Running().Any(process => process.Id == pid);
    }

    // The form: title, level key, then Añadir. The form closes after it adds.
    public void AddPriority(string title, string level = "LevelMedium")
    {
        Click("NewPriorityButton");
        Click("NewPriorityTitle");
        Type(title);
        Click(level);
        Click("AddButton");
        WaitGone("AddButton");
    }

    public string RowId(string title) =>
        Until(
            () => FindAll("PriorityRow_").FirstOrDefault(row => row.Current.Name == title)?.Current.AutomationId["PriorityRow_".Length..],
            $"the row {title} shows");

    public void Dispose()
    {
        try
        {
            if (Running().Any() && Find("QuitButton") is not null)
            {
                Quit();
            }
        }
        catch (Exception error) when (error is TimeoutException or ElementNotAvailableException or InvalidOperationException)
        {
        }

        foreach (var process in _started)
        {
            if (!process.HasExited)
            {
                process.Kill();
                process.WaitForExit(5000);
            }

            process.Dispose();
        }

        for (var attempt = 0; attempt < 10 && Directory.Exists(DataDir); attempt++)
        {
            try
            {
                Directory.Delete(DataDir, recursive: true);
            }
            catch (IOException)
            {
                Thread.Sleep(300);
            }
        }
    }

    private static T Until<T>(Func<T?> probe, string what)
    {
        var deadline = DateTime.UtcNow + Patience;
        while (true)
        {
            var value = probe();
            if (value is not null && value is not false)
            {
                return value;
            }

            if (DateTime.UtcNow > deadline)
            {
                throw new TimeoutException($"Waited {Patience.TotalSeconds} s for {what}.");
            }

            Thread.Sleep(150);
        }
    }

    private static string DefaultExePath()
    {
        var output = new DirectoryInfo(AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar));
        var configuration = output.Parent!.Name;
        var windows = output.Parent.Parent!.Parent!.Parent!.Parent!.FullName;
        return Path.Combine(windows, "src", "DailyZGT", "bin", configuration, "net10.0-windows10.0.19041.0", "DailyZGT.exe");
    }

    private IEnumerable<Process> Running() =>
        _started.Where(process =>
        {
            process.Refresh();
            return !process.HasExited && IsTheExe(process);
        });

    private static bool IsTheExe(Process process)
    {
        try
        {
            return string.Equals(process.MainModule?.FileName, ExePath, StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return false;
        }
    }

    private IEnumerable<AutomationElement> Windows()
    {
        var ids = Running().Select(process => process.Id).ToHashSet();
        if (ids.Count == 0)
        {
            yield break;
        }

        foreach (AutomationElement window in AutomationElement.RootElement.FindAll(TreeScope.Children, Condition.TrueCondition))
        {
            if (ids.Contains(window.Current.ProcessId))
            {
                yield return window;
            }
        }
    }

    private static class Native
    {
        private const uint MouseLeftDown = 0x2;
        private const uint MouseLeftUp = 0x4;
        private const uint KeyUp = 0x2;
        private const uint KeyUnicode = 0x4;

        private static readonly Dictionary<string, byte> Keys = new()
        {
            ["enter"] = 0x0D,
            ["escape"] = 0x1B,
            ["tab"] = 0x09,
            ["ctrl"] = 0x11,
            ["alt"] = 0x12,
            ["shift"] = 0x10,
        };

        public static void Click(int x, int y)
        {
            SetCursorPos(x, y);
            Thread.Sleep(60);
            mouse_event(MouseLeftDown, 0, 0, 0, 0);
            Thread.Sleep(40);
            mouse_event(MouseLeftUp, 0, 0, 0, 0);
        }

        public static void Key(string chord)
        {
            var keys = chord.ToLowerInvariant().Split('+').Select(key => Keys[key]).ToList();
            foreach (var key in keys)
            {
                keybd_event(key, 0, 0, 0);
                Thread.Sleep(20);
            }

            for (var index = keys.Count - 1; index >= 0; index--)
            {
                keybd_event(keys[index], 0, KeyUp, 0);
                Thread.Sleep(20);
            }
        }

        public static void Type(string text)
        {
            foreach (var character in text)
            {
                var inputs = new Input[]
                {
                    new() { type = 1, ki = new KeyboardInput { wScan = character, dwFlags = KeyUnicode } },
                    new() { type = 1, ki = new KeyboardInput { wScan = character, dwFlags = KeyUnicode | KeyUp } },
                };
                SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
                Thread.Sleep(15);
            }
        }

        public static int ForegroundProcessId()
        {
            GetWindowThreadProcessId(GetForegroundWindow(), out var pid);
            return (int)pid;
        }

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        private static extern void mouse_event(uint flags, uint dx, uint dy, uint data, nint extra);

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte vk, byte scan, uint flags, nint extra);

        [DllImport("user32.dll")]
        private static extern uint SendInput(uint count, Input[] inputs, int size);

        [DllImport("user32.dll")]
        private static extern nint GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(nint window, out uint pid);

        [StructLayout(LayoutKind.Sequential)]
        private struct KeyboardInput
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public nint dwExtraInfo;
        }

        // The union of INPUT is as large as its mouse member, so SendInput accepts the size.
        [StructLayout(LayoutKind.Sequential)]
        private struct MouseInput
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public nint dwExtraInfo;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct Input
        {
            [FieldOffset(0)]
            public uint type;

            [FieldOffset(8)]
            public KeyboardInput ki;

            [FieldOffset(8)]
            public MouseInput mi;
        }
    }
}
