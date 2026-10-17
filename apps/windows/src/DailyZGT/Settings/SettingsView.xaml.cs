using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using DailyZGT.Core.App;
using DailyZGT.Platform;

namespace DailyZGT.Settings;

// F18. The four settings rows. The DataContext is the PanelState. Every switch shows the model's value
// after a click, so a change Windows refused flips back.
public partial class SettingsView : UserControl
{
    private readonly ISystemSettings systemSettings = new WindowsSettingsOpener();
    private PanelState? panel;
    private bool rendering;

    public SettingsView()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private ShortcutSettings? Shortcut => panel?.Shortcut;

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (panel is not null)
        {
            panel.PropertyChanged -= OnModelChanged;
            panel.Startup.PropertyChanged -= OnModelChanged;
            panel.Shortcut.PropertyChanged -= OnModelChanged;
        }

        panel = e.NewValue as PanelState;
        if (panel is not null)
        {
            panel.PropertyChanged += OnModelChanged;
            panel.Startup.PropertyChanged += OnModelChanged;
            panel.Shortcut.PropertyChanged += OnModelChanged;
        }

        Render();
    }

    private void OnModelChanged(object? sender, PropertyChangedEventArgs e) => Render();

    private void Render()
    {
        rendering = true;
        try
        {
            RenderNow();
        }
        finally
        {
            rendering = false;
        }
    }

    private void RenderNow()
    {
        if (panel is null)
        {
            return;
        }

        var texts = UiText.Current;
        Show(LoginSwitch, panel.Startup.IsOn);
        Show(TodayLimitSwitch, panel.TodayLimitIsOn);
        Show(TrayTitleSwitch, panel.TrayTitleIsOn);
        LoginApproval.Visibility = Visible(panel.Startup.NeedsApproval);
        LoginFailed.Visibility = Visible(panel.Startup.ChangeFailed);

        var shortcut = panel.Shortcut;
        var recording = shortcut.Recording == ShortcutRecording.Recording;
        ShortcutDetail.Text = shortcut.IsSet ? texts.ShortcutDetail : texts.ShortcutClearedDetail;
        ShortcutText.Text = recording
            ? texts.ShortcutRecording
            : shortcut.Shortcut is { } keys ? ShortcutFormatter.Format(CaptureHotkey.ToPlatform(keys), texts) : texts.ShortcutEmpty;
        ShortcutText.SetResourceReference(TextBlock.ForegroundProperty, recording || !shortcut.IsSet ? "Brush.Panel.Muted" : "Brush.Panel.Text");
        ShortcutClear.Visibility = Visible(shortcut.IsSet && !recording);
        ShortcutProblem.Text = shortcut.Failure switch
        {
            ShortcutFailure.InvalidShortcut => texts.ShortcutNeedsModifier,
            ShortcutFailure.InUse or ShortcutFailure.Unavailable => texts.ShortcutTaken,
            _ => "",
        };
        ShortcutProblem.Visibility = Visible(shortcut.Failure is not null);
    }

    private static void Show(ToggleButton toggle, bool isOn) => toggle.SetCurrentValue(ToggleButton.IsCheckedProperty, isOn);

    private static Visibility Visible(bool shown) => shown ? Visibility.Visible : Visibility.Collapsed;

    private void OnBack(object sender, RoutedEventArgs e) => panel?.CloseSettings();

    // Checked and Unchecked, not Click, so a UI Automation Toggle acts like a click.
    private void OnLogin(object sender, RoutedEventArgs e) => Change(() => panel!.Startup.Set(LoginSwitch.IsChecked == true));

    private void OnTodayLimit(object sender, RoutedEventArgs e) => Change(() => panel!.TodayLimitIsOn = TodayLimitSwitch.IsChecked == true);

    private void OnTrayTitle(object sender, RoutedEventArgs e) => Change(() => panel!.TrayTitleIsOn = TrayTitleSwitch.IsChecked == true);

    private void Change(Action change)
    {
        if (rendering || panel is null)
        {
            return;
        }

        change();
        Render();
    }

    private void OnOpenStartupApps(object sender, RoutedEventArgs e) => systemSettings.OpenStartupApps();

    private void OnShortcutClick(object sender, RoutedEventArgs e)
    {
        ShortcutField.Focus();
        Shortcut?.StartRecording();
    }

    private void OnShortcutClear(object sender, RoutedEventArgs e) => Shortcut?.Clear();

    private void OnShortcutLostFocus(object sender, KeyboardFocusChangedEventArgs e)
    {
        if (Shortcut is { Recording: ShortcutRecording.Recording } shortcut)
        {
            shortcut.CancelRecording();
        }
    }

    // While recording, every key goes to the recorder: Escape stops, Delete clears, a lone modifier waits
    // for the rest of the combination, and any other key is the shortcut.
    private void OnShortcutKey(object sender, KeyEventArgs e)
    {
        if (Shortcut is not { Recording: ShortcutRecording.Recording } shortcut)
        {
            return;
        }

        e.Handled = true;
        var key = e.Key switch
        {
            Key.System => e.SystemKey,
            Key.ImeProcessed => e.ImeProcessedKey,
            _ => e.Key,
        };
        switch (key)
        {
            case Key.Escape:
                shortcut.CancelRecording();
                return;
            case Key.Delete:
                shortcut.Clear();
                return;
        }

        if (WpfShortcut.IsModifier(key))
        {
            return;
        }

        shortcut.Record(CaptureHotkey.ToCore(WpfShortcut.Read(key, Keyboard.Modifiers)));
    }
}
