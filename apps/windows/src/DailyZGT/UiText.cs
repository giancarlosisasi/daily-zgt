using DailyZGT.Core.Localization;

namespace DailyZGT;

public static class UiText
{
    public static Texts Current { get; set; } = Texts.For(AppLanguageResolver.FromEnvironment());
}
