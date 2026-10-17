using System.Windows;
using System.Windows.Controls;

namespace DailyZGT.Priorities;

// F07. Lays out the confirm bar: the title, the open subtasks line and the buttons. The title never gets
// cut. When the title and the buttons fit on one line the buttons sit at the right and the line wraps under
// the title. When they do not (a longer translation, a narrow row), the buttons move under the text.
public sealed class ConfirmLayout : Panel
{
    private const double Gap = 8;
    private const double StackGap = 6;

    private bool _stacked;

    private UIElement Title => InternalChildren[0];

    private UIElement Hint => InternalChildren[1];

    private UIElement Buttons => InternalChildren[2];

    protected override Size MeasureOverride(Size availableSize)
    {
        Buttons.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        Title.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        var width = availableSize.Width;
        var buttons = Buttons.DesiredSize;
        var title = Title.DesiredSize;
        _stacked = !double.IsInfinity(width) && title.Width + Gap + buttons.Width > width;

        var textWidth = _stacked || double.IsInfinity(width) ? width : width - Gap - buttons.Width;
        Hint.Measure(new Size(textWidth, double.PositiveInfinity));
        var textHeight = title.Height + Hint.DesiredSize.Height;
        if (_stacked)
        {
            return new Size(Math.Max(title.Width, buttons.Width), textHeight + StackGap + buttons.Height);
        }

        var used = Math.Max(title.Width, Hint.DesiredSize.Width) + Gap + buttons.Width;
        return new Size(double.IsInfinity(width) ? used : width, Math.Max(textHeight, buttons.Height));
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        var title = Title.DesiredSize;
        var hint = Hint.DesiredSize;
        var buttons = Buttons.DesiredSize;
        var textHeight = title.Height + hint.Height;
        if (_stacked)
        {
            Title.Arrange(new Rect(0, 0, title.Width, title.Height));
            Hint.Arrange(new Rect(0, title.Height, finalSize.Width, hint.Height));
            Buttons.Arrange(new Rect(finalSize.Width - buttons.Width, textHeight + StackGap, buttons.Width, buttons.Height));
            return finalSize;
        }

        var textTop = Math.Max(0, (finalSize.Height - textHeight) / 2);
        var textWidth = Math.Max(0, finalSize.Width - Gap - buttons.Width);
        Title.Arrange(new Rect(0, textTop, title.Width, title.Height));
        Hint.Arrange(new Rect(0, textTop + title.Height, textWidth, hint.Height));
        Buttons.Arrange(new Rect(finalSize.Width - buttons.Width, (finalSize.Height - buttons.Height) / 2, buttons.Width, buttons.Height));
        return finalSize;
    }
}
