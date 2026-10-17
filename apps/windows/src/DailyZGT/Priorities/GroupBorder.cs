using System.Windows;
using System.Windows.Automation.Peers;
using System.Windows.Controls;

namespace DailyZGT.Priorities;

// A Border that UI Automation sees as a group, so its AutomationId reaches the end-to-end tests. A plain
// Border or panel has no automation peer and its AutomationId is lost.
public sealed class GroupBorder : Border
{
    protected override AutomationPeer OnCreateAutomationPeer() => new GroupPeer(this);

    private sealed class GroupPeer(FrameworkElement owner) : FrameworkElementAutomationPeer(owner)
    {
        protected override AutomationControlType GetAutomationControlTypeCore() => AutomationControlType.Group;

        protected override string GetClassNameCore() => nameof(GroupBorder);
    }
}
