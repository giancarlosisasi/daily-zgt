using DailyZGT.Capture;
using DailyZGT.Platform;
using DailyZGT.Shell;

namespace DailyZGT.Platform.Tests;

public class ShellPlacementTests
{
    private const int Gap = 12;
    private static readonly ScreenSize Panel = new(360, 400);
    private static readonly ScreenRect Work = new(0, 0, 2560, 1392);
    private static readonly ScreenRect BottomTaskbar = new(0, 1392, 2560, 1440);

    [Fact]
    public void Panel_sits_over_an_icon_on_the_bottom_taskbar()
    {
        var icon = new ScreenRect(2000, 1392, 2032, 1440);

        var at = PanelPlacement.TopLeft(Panel, Work, TaskbarEdge.Bottom, BottomTaskbar, icon, Gap);

        Assert.Equal(new ScreenPoint(2016 - 180, 1392 - Gap - 400), at);
    }

    [Fact]
    public void Panel_stays_inside_the_work_area_when_the_icon_is_near_the_corner()
    {
        var icon = new ScreenRect(2500, 1392, 2532, 1440);

        var at = PanelPlacement.TopLeft(Panel, Work, TaskbarEdge.Bottom, BottomTaskbar, icon, Gap);

        Assert.Equal(2560 - Gap - 360, at.X);
    }

    [Fact]
    public void Panel_goes_to_the_corner_when_the_icon_is_in_the_overflow_flyout()
    {
        var overflow = new ScreenRect(2218, 1295, 2258, 1335);

        var at = PanelPlacement.TopLeft(Panel, Work, TaskbarEdge.Bottom, BottomTaskbar, overflow, Gap);

        Assert.Equal(new ScreenPoint(2560 - Gap - 360, 1392 - Gap - 400), at);
    }

    [Fact]
    public void Panel_goes_to_the_corner_when_Windows_does_not_report_the_icon()
    {
        var at = PanelPlacement.TopLeft(Panel, Work, TaskbarEdge.Bottom, null, null, Gap);

        Assert.Equal(new ScreenPoint(2560 - Gap - 360, 1392 - Gap - 400), at);
    }

    [Fact]
    public void Panel_hangs_under_a_top_taskbar()
    {
        var work = new ScreenRect(0, 48, 2560, 1440);
        var taskbar = new ScreenRect(0, 0, 2560, 48);
        var icon = new ScreenRect(2000, 0, 2032, 48);

        var at = PanelPlacement.TopLeft(Panel, work, TaskbarEdge.Top, taskbar, icon, Gap);

        Assert.Equal(new ScreenPoint(2016 - 180, 48 + Gap), at);
    }

    [Fact]
    public void Panel_stands_beside_a_left_taskbar_level_with_the_icon()
    {
        var work = new ScreenRect(48, 0, 2560, 1440);
        var taskbar = new ScreenRect(0, 0, 48, 1440);
        var icon = new ScreenRect(0, 1200, 48, 1232);

        var at = PanelPlacement.TopLeft(Panel, work, TaskbarEdge.Left, taskbar, icon, Gap);

        Assert.Equal(new ScreenPoint(48 + Gap, 1216 - 200), at);
    }

    [Fact]
    public void Panel_grows_at_most_to_the_work_area_less_the_gaps()
    {
        Assert.Equal(1392 - Gap * 2, PanelPlacement.MaxHeight(Work, Gap));
    }

    [Fact]
    public void Capture_window_opens_centered_near_the_top_of_the_work_area()
    {
        var at = CapturePlacement.TopLeft(new ScreenSize(416, 175), new ScreenRect(2560, 0, 4480, 1040), 80);

        Assert.Equal(new ScreenPoint(2560 + (1920 - 416) / 2, 80), at);
    }

    [Fact]
    public void Capture_window_stays_on_a_short_screen()
    {
        var at = CapturePlacement.TopLeft(new ScreenSize(416, 175), new ScreenRect(0, 0, 800, 200), 80);

        Assert.Equal(new ScreenPoint(192, 25), at);
    }

    [Theory]
    [InlineData(new string[0], false, false, null)]
    [InlineData(new[] { "--show-panel" }, true, false, null)]
    [InlineData(new[] { "--show-capture" }, false, true, null)]
    [InlineData(new[] { "-ToastActivated", "--toast", "alert_id=a1" }, false, false, "alert_id=a1")]
    [InlineData(new[] { "--toast" }, false, false, null)]
    public void Launch_arguments_say_what_to_open(string[] args, bool panel, bool capture, string? toast)
    {
        Assert.Equal(new LaunchRequest(panel, capture, toast), LaunchRequest.Parse(args));
    }

    [Fact]
    public void A_toast_activation_travels_with_the_other_arguments()
    {
        var request = LaunchRequest.Parse(LaunchRequest.WithToast(["--show-panel"], "alert_id=a1;action=open"));

        Assert.Equal(new LaunchRequest(true, false, "alert_id=a1;action=open"), request);
        Assert.True(request.AsksForAnything);
        Assert.False(LaunchRequest.Parse([]).AsksForAnything);
    }
}
