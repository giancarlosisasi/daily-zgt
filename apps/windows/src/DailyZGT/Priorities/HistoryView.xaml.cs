using System.ComponentModel;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using DailyZGT.Core.App;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;

namespace DailyZGT.Priorities;

// F08. The history of the open list: done priorities older than 24 hours, by day. The shell sets
// DataContext to the PanelState and shows the view while the page is History.
public partial class HistoryView : UserControl
{
    private HistoryModel? _model;

    public HistoryView()
    {
        InitializeComponent();
        Loaded += (_, _) => Attach();
        Unloaded += (_, _) => Detach();
        DataContextChanged += (_, _) =>
        {
            if (IsLoaded)
            {
                Attach();
            }
        };
    }

    private void Attach()
    {
        Detach();
        if (DataContext is PanelState panel)
        {
            _model = new HistoryModel(panel);
            Root.DataContext = _model;
            panel.PropertyChanged += OnPanelChanged;
        }
    }

    private void Detach()
    {
        if (_model is { } model)
        {
            model.Panel.PropertyChanged -= OnPanelChanged;
            model.Dispose();
        }

        _model = null;
        Root.DataContext = null;
    }

    // F22. The history slides in when it opens.
    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PanelState.Page) && sender is PanelState { Page: PanelPage.History })
        {
            Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () => Moves.Play(Root, EnterKind.SlideIn));
        }
    }
}

public sealed class HistoryModel : ObservableModel, IDisposable
{
    private readonly Texts _texts = UiText.Current;
    private IReadOnlyList<HistoryGroupItem> _groups = [];

    public HistoryModel(PanelState panel)
    {
        Panel = panel;
        Back = new RelayCommand(panel.CloseHistory);
        panel.Store.Changed += OnChanged;
        panel.Clock.MinuteTicked += OnChanged;
        panel.PropertyChanged += OnPanelChanged;
        Refresh();
    }

    public PanelState Panel { get; }

    public ICommand Back { get; }

    public string ListTitle => Panel.Scope.Title(_texts);

    public IReadOnlyList<HistoryGroupItem> Groups
    {
        get => _groups;
        private set
        {
            if (Set(ref _groups, value))
            {
                Raise(nameof(HasGroups));
            }
        }
    }

    public bool HasGroups => Groups.Count > 0;

    public void Dispose()
    {
        Panel.Store.Changed -= OnChanged;
        Panel.Clock.MinuteTicked -= OnChanged;
        Panel.PropertyChanged -= OnPanelChanged;
    }

    private void Refresh()
    {
        var now = Panel.Clock.Now;
        var older = Panel.Store.DonePriorities(Panel.Scope)
            .Where(priority => DoneWindow.IsHistory(priority.DoneAt!.Value, now));
        Groups = DoneHistory.Groups(older)
            .Select(day => new HistoryGroupItem(
                _texts.HistoryGroupTitle(day.Date, now),
                day.Priorities.Select(priority => new DoneRowItem(priority, Panel.Flow, inHistory: true)).ToList()))
            .ToList();
    }

    private void OnChanged(object? sender, EventArgs e) => Refresh();

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PanelState.Scope))
        {
            Raise(nameof(ListTitle));
            Refresh();
        }
    }
}
