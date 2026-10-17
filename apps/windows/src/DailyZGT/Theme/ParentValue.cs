using System.Windows;
using System.Windows.Data;
using System.Windows.Markup;

namespace DailyZGT.Theme;

// A template part's binding to an attached property of the templated parent, such as
// {theme:ParentValue theme:KeyFace.Radius}. A Binding path written as (theme:KeyFace.Radius) resolves its prefix
// late, against the xmlns of the view that uses the style, so the style breaks in a view without a theme
// prefix. Here the XAML reader resolves the property in this dictionary and the path holds the property itself.
[MarkupExtensionReturnType(typeof(object))]
public sealed class ParentValue : MarkupExtension
{
    public ParentValue()
    {
    }

    public ParentValue(DependencyProperty property) => Property = property;

    [ConstructorArgument("property")]
    public DependencyProperty? Property { get; set; }

    public IValueConverter? Converter { get; set; }

    public object? ConverterParameter { get; set; }

    public override object ProvideValue(IServiceProvider serviceProvider) =>
        new Binding
        {
            Path = new PropertyPath(Property ?? throw new InvalidOperationException("ParentValue needs a property.")),
            RelativeSource = RelativeSource.TemplatedParent,
            Converter = Converter,
            ConverterParameter = ConverterParameter,
        }.ProvideValue(serviceProvider);
}
