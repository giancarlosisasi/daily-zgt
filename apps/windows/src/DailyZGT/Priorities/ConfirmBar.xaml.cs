using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace DailyZGT.Priorities;

// F07. "¿Marcar como hecha?" with the open subtasks line, Cancelar and Hecha. Under a row and in the detail view.
public partial class ConfirmBar : UserControl
{
    public static readonly DependencyProperty HintProperty = DependencyProperty.Register(
        nameof(Hint), typeof(string), typeof(ConfirmBar), new PropertyMetadata(null));

    public static readonly DependencyProperty CancelCommandProperty = DependencyProperty.Register(
        nameof(CancelCommand), typeof(ICommand), typeof(ConfirmBar), new PropertyMetadata(null));

    public static readonly DependencyProperty ConfirmCommandProperty = DependencyProperty.Register(
        nameof(ConfirmCommand), typeof(ICommand), typeof(ConfirmBar), new PropertyMetadata(null));

    public ConfirmBar()
    {
        InitializeComponent();
    }

    public string? Hint
    {
        get => (string?)GetValue(HintProperty);
        set => SetValue(HintProperty, value);
    }

    public ICommand? CancelCommand
    {
        get => (ICommand?)GetValue(CancelCommandProperty);
        set => SetValue(CancelCommandProperty, value);
    }

    public ICommand? ConfirmCommand
    {
        get => (ICommand?)GetValue(ConfirmCommandProperty);
        set => SetValue(ConfirmCommandProperty, value);
    }
}
