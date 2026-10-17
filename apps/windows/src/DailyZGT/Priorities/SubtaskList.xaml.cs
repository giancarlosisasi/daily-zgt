using System.Windows;
using System.Windows.Controls;

namespace DailyZGT.Priorities;

// F10. The subtasks and the "Añadir subtarea y Enter" field, bound to a SubtaskListItem. Under a row the rows
// sit 1 point apart, in the detail view 4 points apart.
public partial class SubtaskList : UserControl
{
    public static readonly DependencyProperty RowGapProperty = DependencyProperty.Register(
        nameof(RowGap), typeof(Thickness), typeof(SubtaskList), new PropertyMetadata(new Thickness(0, 0, 0, 1)));

    public static readonly DependencyProperty FieldGapProperty = DependencyProperty.Register(
        nameof(FieldGap), typeof(Thickness), typeof(SubtaskList), new PropertyMetadata(new Thickness(0, 2, 0, 0)));

    public SubtaskList()
    {
        InitializeComponent();
    }

    public Thickness RowGap
    {
        get => (Thickness)GetValue(RowGapProperty);
        set => SetValue(RowGapProperty, value);
    }

    public Thickness FieldGap
    {
        get => (Thickness)GetValue(FieldGapProperty);
        set => SetValue(FieldGapProperty, value);
    }
}
