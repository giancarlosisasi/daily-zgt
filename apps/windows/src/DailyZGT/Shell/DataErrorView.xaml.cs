using System.Windows.Controls;

namespace DailyZGT.Shell;

// F02. The panel when the app could not open its data: the message and a footer with only Salir.
public partial class DataErrorView : UserControl
{
    public DataErrorView()
    {
        InitializeComponent();
    }

    public FooterView FooterBar => Footer;
}
