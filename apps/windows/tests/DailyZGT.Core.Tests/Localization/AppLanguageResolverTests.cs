using System.Globalization;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Tests.Localization;

public class AppLanguageResolverTests
{
    [Theory]
    [InlineData("es-ES", AppLanguage.Es)]
    [InlineData("es-MX", AppLanguage.Es)]
    [InlineData("es-419", AppLanguage.Es)]
    [InlineData("es", AppLanguage.Es)]
    [InlineData("pt-BR", AppLanguage.Pt)]
    [InlineData("pt-PT", AppLanguage.Pt)]
    [InlineData("en-US", AppLanguage.En)]
    [InlineData("en-GB", AppLanguage.En)]
    [InlineData("fr-FR", AppLanguage.En)]
    [InlineData("ja-JP", AppLanguage.En)]
    [InlineData("et-EE", AppLanguage.En)]
    [InlineData("", AppLanguage.En)]
    public void The_culture_picks_the_language(string cultureName, AppLanguage expected)
    {
        var culture = CultureInfo.GetCultureInfo(cultureName);

        Assert.Equal(expected, AppLanguageResolver.Resolve(culture, null));
    }

    [Theory]
    [InlineData("es", AppLanguage.Es)]
    [InlineData("en", AppLanguage.En)]
    [InlineData("pt", AppLanguage.Pt)]
    [InlineData("PT", AppLanguage.Pt)]
    [InlineData(" en ", AppLanguage.En)]
    [InlineData("pt-BR", AppLanguage.Pt)]
    public void A_valid_override_wins_over_the_culture(string overrideValue, AppLanguage expected)
    {
        var culture = CultureInfo.GetCultureInfo(expected == AppLanguage.Es ? "pt-BR" : "es-ES");

        Assert.Equal(expected, AppLanguageResolver.Resolve(culture, overrideValue));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("fr")]
    [InlineData("spanish")]
    public void An_empty_or_unknown_override_is_ignored(string? overrideValue)
    {
        Assert.Equal(AppLanguage.Pt, AppLanguageResolver.Resolve(CultureInfo.GetCultureInfo("pt-BR"), overrideValue));
        Assert.Equal(AppLanguage.En, AppLanguageResolver.Resolve(CultureInfo.GetCultureInfo("de-DE"), overrideValue));
    }

    [Fact]
    public void The_invariant_culture_gives_English()
    {
        Assert.Equal(AppLanguage.En, AppLanguageResolver.Resolve(CultureInfo.InvariantCulture, null));
    }

    [Theory]
    [InlineData(AppLanguage.Es)]
    [InlineData(AppLanguage.En)]
    [InlineData(AppLanguage.Pt)]
    public void Each_language_has_its_catalog(AppLanguage language)
    {
        Assert.Equal(language, Texts.For(language).Language);
    }
}
