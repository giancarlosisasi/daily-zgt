using DailyZGT.Platform;
using CommunityToolkit.WinUI.Notifications;

// Throwaway spike: proves scheduled toasts work for an unpackaged .NET app.
//   ToastSpike.exe run            schedule +10s, list, remove, list, schedule +10s, list, wait for it to fire
//   ToastSpike.exe schedule <s>   schedule one toast <s> seconds ahead and exit at once (tests delivery with the app closed)
//   ToastSpike.exe list           print scheduled and delivered toasts
//   ToastSpike.exe clear          remove every scheduled and delivered toast
//   ToastSpike.exe wait <s>       stay alive <s> seconds and print activations
//   ToastSpike.exe shot <delay> <png> <count>   save screenshots of the whole desktop

static void Log(string line)
{
    var text = $"{DateTime.Now:HH:mm:ss.fff} [{Environment.ProcessId}] {line}";
    Console.WriteLine(text);
    System.IO.File.AppendAllText(System.IO.Path.Combine(AppContext.BaseDirectory, "spike.log"), text + Environment.NewLine);
}

var passive = args.Length > 0 && args[0] is "invoke" or "shot" or "activate";
var coldStart = !passive && ToastNotificationManagerCompat.WasCurrentProcessToastActivated();
if (coldStart)
{
    Log("process was started by a toast activation");
}

if (passive)
{
    Log($"mode={args[0]}");
}

using var center = new WindowsToastCenter();
center.Activated += (_, a) => Log($"ACTIVATED alert={a.AlertId} priority={a.PriorityId} action={a.Action}");
var mode = coldStart ? "wait" : args.Length > 0 ? args[0] : "run";
if (coldStart)
{
    args = ["wait", "6"];
}

if (!passive)
{
    center.Start();
}

if (!passive)
{
    Log($"mode={mode} availability={center.Availability}");
}

void Dump(string label)
{
    var pending = center.Pending();
    Log($"{label}: pending={pending.Count} delivered=[{string.Join(",", center.DeliveredIds())}]");
    foreach (var p in pending)
    {
        Log($"  pending id={p.Id} fire={p.FireAt:HH:mm:ss} priority={p.PriorityId} title='{p.Title}' body='{p.Body}'");
    }
}

ToastRequest Make(string id, int seconds) => new(
    id,
    "Vence en 30 min",
    $"Prioridad de prueba {id}",
    DateTime.Now.AddSeconds(seconds),
    "priority-" + id);

switch (mode)
{
    case "run":
        center.Schedule(Make("first-alert", 10));
        Dump("after schedule #1");
        center.RemovePending(["first-alert"]);
        Dump("after remove");
        center.Schedule(Make("second-alert", 10));
        Dump("after schedule #2");
        Log("waiting for the toast to fire (20 s)");
        await Task.Delay(TimeSpan.FromSeconds(20));
        Dump("after fire");
        break;
    case "schedule":
        center.Schedule(Make("closed-app-alert", int.Parse(args[1])));
        Dump("scheduled, now exiting");
        break;
    case "list":
        Dump("state");
        break;
    case "clear":
        center.RemovePending(center.Pending().Select(p => p.Id));
        center.RemoveDelivered(center.DeliveredIds());
        Dump("cleared");
        break;
    case "now":
        center.Show(Make("now-alert", 0));
        await Task.Delay(TimeSpan.FromSeconds(3));
        Dump("after show");
        break;
    case "raw":
        try
        {
            var lead = int.Parse(args[1]);
            var xml = new Windows.Data.Xml.Dom.XmlDocument();
            xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>raw</text></binding></visual></toast>");
            ToastNotificationManagerCompat.CreateToastNotifier().AddToSchedule(new Windows.UI.Notifications.ScheduledToastNotification(xml, DateTimeOffset.Now.AddSeconds(lead)) { Tag = "raw", Group = "alerts" });
            Log($"raw schedule +{lead}s accepted");
        }
        catch (Exception error)
        {
            Log($"raw schedule rejected: {error.Message}");
        }

        break;
    case "activate":
        Log(Screenshot.Activate(args[1], args[2]));
        break;
    case "uninstall":
        ToastNotificationManagerCompat.Uninstall();
        Log("uninstalled toast registration");
        break;
    case "invoke":
        Log(Screenshot.Invoke(args[1]));
        break;
    case "shot":
        Screenshot.Capture(int.Parse(args[1]), args[2], int.Parse(args[3]));
        break;
    case "wait":
        await Task.Delay(TimeSpan.FromSeconds(int.Parse(args[1])));
        Dump("after wait");
        break;
}

[System.Runtime.InteropServices.ComImport]
[System.Runtime.InteropServices.Guid("53E31837-6600-4A81-9395-75CFFE746F94")]
[System.Runtime.InteropServices.InterfaceType(System.Runtime.InteropServices.ComInterfaceType.InterfaceIsIUnknown)]
interface INotificationActivationCallback
{
    void Activate(
        [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string appUserModelId,
        [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string invokedArgs,
        nint data,
        uint count);
}

static class Screenshot
{
    [System.Runtime.InteropServices.DllImport("ole32.dll")]
    private static extern int CoCreateInstance(in Guid clsid, nint outer, uint context, ref Guid iid, out nint instance);

    public static string Activate(string clsid, string arguments)
    {
        var iid = typeof(INotificationActivationCallback).GUID;
        var hr = CoCreateInstance(Guid.Parse(clsid), 0, 4, ref iid, out var instance);
        System.Runtime.InteropServices.Marshal.ThrowExceptionForHR(hr);
        var callback = (INotificationActivationCallback)System.Runtime.InteropServices.Marshal.GetObjectForIUnknown(instance);
        callback.Activate("spike", arguments, 0, 0);
        return $"sent activation '{arguments}' through the COM activator";
    }

    public static string Invoke(string name)
    {
        if (name == "dump")
        {
            var root = System.Windows.Automation.AutomationElement.RootElement;
            foreach (System.Windows.Automation.AutomationElement child in root.FindAll(System.Windows.Automation.TreeScope.Children, System.Windows.Automation.Condition.TrueCondition))
            {
                Console.WriteLine($"top: name='{child.Current.Name}' class={child.Current.ClassName} pid={child.Current.ProcessId}");
            }

            return "dumped";
        }

        for (var i = 0; i < 20; i++)
        {
            var condition = new System.Windows.Automation.PropertyCondition(System.Windows.Automation.AutomationElement.NameProperty, name);
            var found = System.Windows.Automation.AutomationElement.RootElement.FindFirst(System.Windows.Automation.TreeScope.Descendants, condition);
            if (found is not null)
            {
                var type = found.Current.ControlType.ProgrammaticName;
                if (!found.TryGetCurrentPattern(System.Windows.Automation.InvokePattern.Pattern, out var pattern))
                {
                    return $"found '{name}' type={type} class={found.Current.ClassName} but no invoke pattern";
                }

                ((System.Windows.Automation.InvokePattern)pattern).Invoke();
                return $"invoked '{name}' type={type} class={found.Current.ClassName}";
            }

            Thread.Sleep(500);
        }

        return $"button '{name}' not found";
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool SetProcessDPIAware();

    public static void Capture(int delaySeconds, string path, int count)
    {
        SetProcessDPIAware();
        Thread.Sleep(TimeSpan.FromSeconds(delaySeconds));
        for (var i = 0; i < count; i++)
        {
            var bounds = System.Drawing.Rectangle.Empty;
            foreach (var screen in System.Windows.Forms.Screen.AllScreens)
            {
                bounds = System.Drawing.Rectangle.Union(bounds, screen.Bounds);
            }

            using var bitmap = new System.Drawing.Bitmap(bounds.Width, bounds.Height);
            using (var graphics = System.Drawing.Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(bounds.Location, System.Drawing.Point.Empty, bounds.Size);
            }

            var file = path.Replace(".png", $"-{i}.png");
            bitmap.Save(file, System.Drawing.Imaging.ImageFormat.Png);
            Console.WriteLine($"saved {file} {bounds.Width}x{bounds.Height}");
            Thread.Sleep(1000);
        }
    }
}
