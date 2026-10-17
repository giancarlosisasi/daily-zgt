using DailyZGT.Core.Rules;

namespace DailyZGT.Core.Tests.Rules;

public class TrayTitleTests
{
    private const string Family = "👨‍👩‍👧‍👦";

    private static string Letters(int count) => new('a', count);

    [Theory]
    [InlineData(23)]
    [InlineData(24)]
    public void ATitleOfUpTo24CharactersStaysWhole(int count) =>
        Assert.Equal(Letters(count), TrayTitle.Text(Letters(count)));

    [Fact]
    public void ATitleOf25CharactersIsCutToTwentyFourWithTheEllipsisLast()
    {
        var text = TrayTitle.Text(Letters(25));

        Assert.Equal(Letters(23) + "…", text);
        Assert.Equal(TrayTitle.MaxLength, text!.Length);
    }

    [Fact]
    public void AVeryLongTitleIsCutToTwentyFourCharacters()
    {
        var text = TrayTitle.Text(Letters(200));

        Assert.Equal(TrayTitle.MaxLength, text!.Length);
        Assert.EndsWith("…", text);
    }

    [Fact]
    public void AnEmojiAtTheBoundaryIsNotCutInHalf() =>
        Assert.Equal(Letters(22) + Family + "…", TrayTitle.Text(Letters(22) + Family + Letters(5)));

    [Fact]
    public void AnEmojiThatEndsAtTwentyFourCharactersStaysWhole()
    {
        var title = Letters(23) + Family;
        Assert.Equal(title, TrayTitle.Text(title));
    }

    [Fact]
    public void AnAccentIsNotCutFromItsLetter()
    {
        var accented = "e" + (char)0x0301;
        Assert.Equal(Letters(22) + accented + "…", TrayTitle.Text(Letters(22) + accented + Letters(4)));
    }

    [Fact]
    public void SpacesBeforeTheEllipsisGoAway() =>
        Assert.Equal(Letters(20) + "…", TrayTitle.Text(Letters(20) + "   " + Letters(10)));

    [Fact]
    public void SpacesAtTheEdgesGoAway() => Assert.Equal("Pagar la luz", TrayTitle.Text("   Pagar la luz  "));

    [Theory]
    [InlineData("Pagar\nla luz")]
    [InlineData("Pagar\r\nla luz")]
    [InlineData("Pagar\rla luz")]
    [InlineData("Pagar\n\nla luz")]
    public void ANewlineBecomesASpace(string title) => Assert.Equal("Pagar la luz", TrayTitle.Text(title));

    [Fact]
    public void ALeadingOrTrailingNewlineLeavesNoSpace() =>
        Assert.Equal("Pagar la luz", TrayTitle.Text("\nPagar la luz\n"));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\n \n")]
    public void NoTitleGivesNoText(string? title) => Assert.Null(TrayTitle.Text(title));
}
