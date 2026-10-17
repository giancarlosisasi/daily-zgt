using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;

namespace DailyZGT.Shell;

// F02. The panel above the footer: the tabs, the scope row with the date, the page, the undo bar and the
// save error line. The DataContext is the ShellModel; the page views get the PanelState.
public partial class PanelShellView : UserControl
{
    private const double SlotGap = 10;

    private ShellModel? shell;
    private FrameworkElement? shownPage;
    private bool rendering;
    private PanelPage? shownKind;

    public PanelShellView()
    {
        InitializeComponent();
    }

    public FooterView FooterBar => Footer;

    private PanelState Panel => shell!.Panel;

    public void Attach(ShellModel model)
    {
        shell = model;
        DataContext = model;
        foreach (var page in new FrameworkElement[] { PrioritiesPage, DetailPage, HistoryPage, SettingsPage, UndoBar })
        {
            page.DataContext = model.Panel;
        }

        NotesPage.DataContext = model.Panel.Notes;
        model.PropertyChanged += OnShellChanged;
        model.Panel.PropertyChanged += OnPanelChanged;
        Footer.SettingsClicked += (_, _) => Panel.ToggleSettings();
        Render();
    }

    private void OnShellChanged(object? sender, PropertyChangedEventArgs e) => RenderFooter();

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e) => Render();

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
        var panel = Panel;
        var browse = panel.Page is PanelPage.Browse;
        Tabs.Visibility = browse ? Visibility.Visible : Visibility.Collapsed;
        TabPriorities.SetCurrentValue(ToggleButton.IsCheckedProperty, panel.Tab == PanelTab.Priorities);
        TabNotes.SetCurrentValue(ToggleButton.IsCheckedProperty, panel.Tab == PanelTab.Notes);
        ScopeToday.SetCurrentValue(ToggleButton.IsCheckedProperty, panel.Scope == PriorityList.Today);
        ScopeWeek.SetCurrentValue(ToggleButton.IsCheckedProperty, panel.Scope == PriorityList.Week);
        ShowPage(panel.Page, PageFor(panel.Page, panel.Tab));
        UndoBar.Visibility = panel.UndoBarVisible ? Visibility.Visible : Visibility.Collapsed;
        OrderSlots(panel.ContentSlots);
        SaveFailed.Visibility = panel.SaveFailed ? Visibility.Visible : Visibility.Collapsed;
        RenderFooter();
    }

    private void RenderFooter()
    {
        if (shell is { } model)
        {
            Footer.Show(model.FooterSummary, model.AlertsOff, model.Panel.Page is PanelPage.Settings);
        }
    }

    private FrameworkElement PageFor(PanelPage page, PanelTab tab) => page switch
    {
        PanelPage.Detail => DetailPage,
        PanelPage.History => HistoryPage,
        PanelPage.Settings => SettingsPage,
        _ => tab == PanelTab.Priorities ? PrioritiesPage : NotesPage,
    };

    // F22. A page that replaces the tabs slides in, the list slides back, and a tab change fades.
    private void ShowPage(PanelPage kind, FrameworkElement page)
    {
        if (page == shownPage)
        {
            shownKind = kind;
            return;
        }

        foreach (UIElement child in Main.Children)
        {
            child.Visibility = child == page ? Visibility.Visible : Visibility.Collapsed;
        }

        if (shownPage is not null && IsLoaded)
        {
            var wasBrowse = shownKind is PanelPage.Browse;
            var isBrowse = kind is PanelPage.Browse;
            if (wasBrowse && isBrowse)
            {
                ShellMotion.FadeIn(page);
            }
            else
            {
                ShellMotion.Slide(page, forward: !isBrowse);
            }
        }

        shownPage = page;
        shownKind = kind;
    }

    // F07. One undo bar element moves between the slots, so a tab change does not replay its entry.
    private void OrderSlots(IReadOnlyList<PanelContentSlot> order)
    {
        var wanted = order.Select(slot => slot == PanelContentSlot.Main ? (FrameworkElement)Main : UndoBar).ToList();
        if (!Slots.Children.Cast<FrameworkElement>().SequenceEqual(wanted))
        {
            Slots.Children.Clear();
            foreach (var element in wanted)
            {
                Slots.Children.Add(element);
            }
        }

        for (var index = 0; index < wanted.Count; index++)
        {
            var gap = index > 0 && wanted[0].Visibility == Visibility.Visible ? SlotGap : 0;
            wanted[index].Margin = new Thickness(0, gap, 0, 0);
        }
    }

    // Checked, not Click, so a UI Automation Select acts like a click.
    private void OnTab(object sender, RoutedEventArgs e)
    {
        if (!rendering)
        {
            Panel.SelectTab(sender == TabNotes ? PanelTab.Notes : PanelTab.Priorities);
        }
    }

    private void OnScope(object sender, RoutedEventArgs e)
    {
        if (!rendering)
        {
            Panel.SelectScope(sender == ScopeWeek ? PriorityList.Week : PriorityList.Today);
        }
    }
}
