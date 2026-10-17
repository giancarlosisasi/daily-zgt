using System.Windows;
using System.Windows.Input;

namespace DailyZGT.Priorities;

// F15. How the Priorities views learn that Windows turned the app's notifications off, and how they ask for
// the notification settings. The shell sets IsOff on the panel root from AlertCoordinator.AlertsAreOff (the
// value flows down to every view) and handles OpenSettings with a CommandBinding that opens
// ms-settings:notifications.
public static class AlertsNotice
{
    public static readonly DependencyProperty IsOffProperty = DependencyProperty.RegisterAttached(
        "IsOff", typeof(bool), typeof(AlertsNotice), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.Inherits));

    public static readonly RoutedCommand OpenSettings = new(nameof(OpenSettings), typeof(AlertsNotice));

    public static bool GetIsOff(DependencyObject d) => (bool)d.GetValue(IsOffProperty);

    public static void SetIsOff(DependencyObject d, bool value) => d.SetValue(IsOffProperty, value);
}
