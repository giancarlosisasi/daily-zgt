using DailyZGT.Platform;

namespace DailyZGT.Platform.Tests;

public class TrayAndStartupTests
{
    [Theory]
    [InlineData(null, null)]
    [InlineData(0, "0")]
    [InlineData(1, "1")]
    [InlineData(9, "9")]
    [InlineData(10, "9+")]
    [InlineData(250, "9+")]
    [InlineData(-3, "0")]
    public void BadgeShowsTheCountUpToNine(int? count, string? expected)
    {
        Assert.Equal(expected, TrayBadge.Text(count));
    }

    [Theory]
    [InlineData(new byte[] { 2, 0, 0, 0 }, false)]
    [InlineData(new byte[] { 6, 0, 0, 0 }, false)]
    [InlineData(new byte[] { 3, 0, 0, 0 }, true)]
    [InlineData(new byte[] { 7, 0, 0, 0 }, true)]
    [InlineData(new byte[0], false)]
    public void StartupApprovedFlagMarksUserDisabled(byte[] data, bool disabled)
    {
        Assert.Equal(disabled, StartupApproved.IsDisabled(data));
    }

    [Fact]
    public void MissingStartupApprovedValueIsNotDisabled()
    {
        Assert.False(StartupApproved.IsDisabled(null));
    }
}
