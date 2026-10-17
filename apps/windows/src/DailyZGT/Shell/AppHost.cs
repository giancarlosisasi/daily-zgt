using System.Windows;
using System.Windows.Threading;
using CommunityToolkit.WinUI.Notifications;
using DailyZGT.Capture;
using DailyZGT.Core.Alerts;
using DailyZGT.Core.App;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Repeat;
using DailyZGT.Core.Store;
using DailyZGT.Platform;
using DailyZGT.Theme;

namespace DailyZGT.Shell;

// The composition root. The first launch owns the tray icon and the panel, opens the store and runs the
// models; a later launch hands its arguments to the first one and exits. When the store does not open,
// the app runs in its data error mode: a tray icon with no count and a panel with the message and Salir.
public sealed class AppHost : IDisposable
{
    private static readonly TimeSpan ToastWait = TimeSpan.FromSeconds(3);

    private readonly Application app;
    private readonly ISingleInstance instance;
    private readonly ITrayIcon tray;
    private readonly PanelWindow panel;
    private readonly Session? session;
    private bool quitting;

    private AppHost(Application app, ISingleInstance instance)
    {
        this.app = app;
        this.instance = instance;
        var texts = UiText.Current;
        tray = new WindowsTrayIcon(texts);
        session = Session.TryOpen(texts);
        FooterView footer;
        if (session is { } ready)
        {
            var view = new PanelShellView();
            view.Attach(ready.Shell);
            footer = view.FooterBar;
            footer.TestAlertClicked += (_, _) => ready.Alerts.SendTestAlert();
            panel = new PanelWindow(view, tray.GetScreenRect);
            panel.Activated += (_, _) => ready.OnPanelActivated();
            panel.Deactivated += (_, _) => ready.Panel.OnDeactivated();
            ready.Alerts.OpenRequested += (_, request) =>
            {
                ready.Panel.ShowInList(request.PriorityId);
                panel.Open(fromToast: true);
            };
            ready.Shell.PropertyChanged += (_, _) => UpdateTray();
            ready.Clock.MinuteTicked += (_, _) => UpdateTray();
        }
        else
        {
            var view = new DataErrorView();
            footer = view.FooterBar;
            panel = new PanelWindow(view, tray.GetScreenRect);
        }

        footer.QuitClicked += (_, _) => Quit();
        tray.Clicked += (_, _) => panel.Toggle();
        tray.OpenRequested += (_, _) => panel.Open(fromToast: false);
        tray.QuitRequested += (_, _) => Quit();
        instance.ArgumentsReceived += (_, args) => Handle(LaunchRequest.Parse(args), forwarded: true);
    }

    // Null when another instance runs: this launch passes its arguments over and the app shuts down.
    public static AppHost? Start(Application app, string[] args)
    {
        var instance = new WindowsSingleInstance();
        if (!instance.IsPrimary)
        {
            HandOver(app, instance, args);
            return null;
        }

        var host = new AppHost(app, instance);
        host.Run(LaunchRequest.Parse(args));
        return host;
    }

    // "Salir" (F19) and the tray menu. The notes save first (F16).
    public void Quit()
    {
        if (quitting)
        {
            return;
        }

        quitting = true;
        session?.Panel.OnQuit();
        app.Shutdown();
    }

    public void Dispose()
    {
        session?.Dispose();
        tray.Dispose();
        instance.Dispose();
    }

    // A launch Windows started for a toast click carries the toast's arguments only through the activation
    // event, so this launch waits for it before it hands over.
    private static void HandOver(Application app, ISingleInstance instance, string[] args)
    {
        void Forward(IReadOnlyList<string> forwarded)
        {
            Desktop.LetAnyProcessTakeFocus();
            instance.ForwardToPrimary(forwarded);
            instance.Dispose();
            app.Shutdown();
        }

        if (!ToastNotificationManagerCompat.WasCurrentProcessToastActivated())
        {
            Forward(args);
            return;
        }

        var done = false;
        var timeout = new DispatcherTimer { Interval = ToastWait };
        void Finish(IReadOnlyList<string> forwarded)
        {
            if (done)
            {
                return;
            }

            done = true;
            timeout.Stop();
            Forward(forwarded);
        }

        ToastNotificationManagerCompat.OnActivated += activation =>
            app.Dispatcher.BeginInvoke(() => Finish(LaunchRequest.WithToast(args, activation.Argument)));
        timeout.Tick += (_, _) => Finish(args);
        timeout.Start();
    }

    private void Run(LaunchRequest request)
    {
        instance.StartListening();
        tray.Show();
        UpdateTray();
        session?.Start();
        Handle(request, forwarded: false);
    }

    // A second launch with no arguments is the person opening the app again, so the panel shows.
    private void Handle(LaunchRequest request, bool forwarded)
    {
        if (request.ToastArguments is { } toast)
        {
            session?.Toasts.Deliver(toast);
        }

        if (request.ShowCapture)
        {
            session?.Capture.Open();
        }

        if (request.ShowPanel || (forwarded && !request.AsksForAnything))
        {
            panel.Open(fromToast: false);
        }
    }

    private void UpdateTray()
    {
        if (session is { } ready)
        {
            tray.Update(ready.Tray.Count, ready.Shell.TrayTooltip);
        }
    }

    // Everything that needs the store. Built only when the store opened.
    private sealed class Session : IDisposable
    {
        private readonly AppStore store;
        private readonly WindowsAnimationSetting animation;
        private readonly MotionPolicy motion;
        private readonly WindowsGlobalHotkey globalHotkey;
        private readonly CaptureHotkey hotkey;
        private readonly ToastAlertSystem alertSystem;
        private readonly RepeatCoordinator repeats;
        private readonly ExternalChangeWatcher watcher;
        private readonly CaptureWindow captureWindow;

        private Session(AppStore store, Texts texts)
        {
            var time = TimeProvider.System;
            var ui = SynchronizationContext.Current
                ?? throw new InvalidOperationException("The app host starts on the UI thread.");
            this.store = store;
            animation = new WindowsAnimationSetting();
            animation.Start();
            Motion.IsReduced = !animation.AnimationsEnabled;
            animation.Changed += (_, _) => Motion.IsReduced = !animation.AnimationsEnabled;
            motion = new MotionPolicy(new AnimationSource(animation), TeclaTokens.Durations.Slow);
            Clock = new UiClock(time, ui);
            globalHotkey = new WindowsGlobalHotkey();
            hotkey = new CaptureHotkey(globalHotkey);
            Panel = new PanelState(
                store,
                Clock,
                motion,
                new StartupSettings(new StartupService(new RegistryStartupRegistration())),
                new ShortcutSettings(hotkey));
            Tray = new TraySummary(store);
            Toasts = new WindowsToastCenter(texts);
            alertSystem = new ToastAlertSystem(Toasts);
            Alerts = new AlertCoordinator(store, alertSystem, texts, time, ui);
            repeats = new RepeatCoordinator(store);
            watcher = new ExternalChangeWatcher(store, ui, time);
            Shell = new ShellModel(Panel, store, Clock, Alerts, Tray, texts);
            Capture = new CaptureModel(store);
            captureWindow = new CaptureWindow(Capture);
        }

        public UiClock Clock { get; }

        public PanelState Panel { get; }

        public TraySummary Tray { get; }

        public WindowsToastCenter Toasts { get; }

        public AlertCoordinator Alerts { get; }

        public ShellModel Shell { get; }

        public CaptureModel Capture { get; }

        public static Session? TryOpen(Texts texts)
        {
            try
            {
                return new Session(AppStore.Open(TimeProvider.System), texts);
            }
            catch (StoreException)
            {
                return null;
            }
        }

        public void Start()
        {
            Panel.Shortcut.Start();
            Capture.Attach(hotkey);
            Clock.DayChanged += (_, _) => CatchUp();
            Guard(repeats.Start);
            try
            {
                Alerts.Start();
            }
            catch (AlertSystemException)
            {
                // Toasts stay off for this run; the panel and the store work without them.
            }
        }

        // F14, F15, F16, F18, F21. The panel came to the front.
        public void OnPanelActivated()
        {
            Panel.OnActivated();
            CatchUp();
        }

        public void Dispose()
        {
            watcher.Dispose();
            captureWindow.Close();
            Alerts.Dispose();
            alertSystem.Dispose();
            Toasts.Dispose();
            repeats.Dispose();
            Capture.Dispose();
            globalHotkey.Dispose();
            Shell.Dispose();
            Tray.Dispose();
            Panel.Dispose();
            motion.Dispose();
            animation.Dispose();
            Clock.Dispose();
            store.Dispose();
        }

        // F14, F21. The daily copies and the alerts catch up with a new day or a return to the front.
        private void CatchUp()
        {
            Guard(() => repeats.Run());
            Alerts.Refresh();
        }

        // The macOS app only logs a failed repeat run. The next change, day change or activation tries again.
        private static void Guard(Action work)
        {
            try
            {
                work();
            }
            catch (StoreException)
            {
            }
        }
    }
}
