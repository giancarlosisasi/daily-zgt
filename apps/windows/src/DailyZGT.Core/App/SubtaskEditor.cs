using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F10. The "Añadir subtarea y Enter" field and the subtask checkboxes of one priority, under a row or in
// the detail view. The field keeps the focus after Enter, so the view never moves it.
public sealed class SubtaskEditor(AppStore store, string priorityId) : ObservableModel
{
    private string _draft = "";
    private bool _saveFailed;

    public string PriorityId => priorityId;

    public string Draft
    {
        get => _draft;
        set => Set(ref _draft, value);
    }

    public bool SaveFailed
    {
        get => _saveFailed;
        private set => Set(ref _saveFailed, value);
    }

    // Enter. A blank text adds nothing and keeps the field as it is.
    public void Add() => Write(() =>
    {
        if (store.AddSubtask(priorityId, Draft) is not null)
        {
            Draft = "";
        }
    });

    // A subtask is done or open again at once, with no confirmation.
    public void Toggle(string subtaskId) => Write(() => store.ToggleSubtask(subtaskId));

    private void Write(Action write)
    {
        try
        {
            write();
            SaveFailed = false;
        }
        catch (StoreException)
        {
            SaveFailed = true;
        }
    }
}
