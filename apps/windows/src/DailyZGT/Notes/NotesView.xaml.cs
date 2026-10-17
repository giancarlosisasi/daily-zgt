using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;

namespace DailyZGT.Notes;

// F16. The note of the day or of the week. The DataContext is PanelState.Notes.
public partial class NotesView : UserControl
{
    private NotesModel? model;

    public NotesView()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (model is not null)
        {
            model.PropertyChanged -= OnModelChanged;
        }

        model = e.NewValue as NotesModel;
        if (model is not null)
        {
            model.PropertyChanged += OnModelChanged;
        }

        Render();
    }

    private void OnModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(NotesModel.Scope) or nameof(NotesModel.SaveFailed))
        {
            Render();
        }
    }

    private void Render()
    {
        if (model is null)
        {
            return;
        }

        var texts = UiText.Current;
        Title.Text = model.Scope == NoteScope.Day ? texts.NotesToday : texts.NotesWeek;
        Hint.Text = model.SaveFailed ? texts.NoteSaveFailed : texts.NotesSavedHint;
    }
}
