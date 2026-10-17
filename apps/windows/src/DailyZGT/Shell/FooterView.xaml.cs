using System.Windows;
using System.Windows.Controls;

namespace DailyZGT.Shell;

// F19. The count, the bell (F15), the gear (F18) and Salir. On a data error only Salir shows.
public partial class FooterView : UserControl
{
    private bool alertsOff;

    public FooterView()
    {
        InitializeComponent();
        ShowDataError();
    }

    public event EventHandler? TestAlertClicked;

    public event EventHandler? SettingsClicked;

    public event EventHandler? QuitClicked;

    public void Show(string summary, bool alertsAreOff, bool settingsOpen)
    {
        Summary.Text = summary;
        alertsOff = alertsAreOff;
        BellButton.Visibility = Visibility.Visible;
        GearButton.Visibility = Visibility.Visible;
        BellIcon.Kind = alertsOff ? "BellSlash" : "Bell";
        BellButton.ToolTip = alertsOff ? UiText.Current.AlertsOff : UiText.Current.TestAlert;
        GearButton.SetResourceReference(ForegroundProperty, settingsOpen ? "Brush.Panel.Text" : "Brush.Panel.Muted");
    }

    public void ShowDataError()
    {
        Summary.Text = "";
        BellButton.Visibility = Visibility.Collapsed;
        GearButton.Visibility = Visibility.Collapsed;
    }

    private void OnBell(object sender, RoutedEventArgs e)
    {
        if (!alertsOff)
        {
            ShellMotion.Ring(BellIcon);
        }

        TestAlertClicked?.Invoke(this, EventArgs.Empty);
    }

    private void OnGear(object sender, RoutedEventArgs e) => SettingsClicked?.Invoke(this, EventArgs.Empty);

    private void OnQuit(object sender, RoutedEventArgs e) => QuitClicked?.Invoke(this, EventArgs.Empty);
}
