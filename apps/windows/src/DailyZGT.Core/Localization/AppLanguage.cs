using System.Globalization;

namespace DailyZGT.Core.Localization;

public enum AppLanguage { Es, En, Pt }

public static class AppLanguageResolver
{
    public const string EnvironmentVariable = "DAILYZGT_LANG";

    // A valid override wins. An empty or unknown override is ignored, so a typo never hides the OS language.
    public static AppLanguage Resolve(CultureInfo culture, string? overrideValue) =>
        TryParse(overrideValue) ?? TryParse(culture.TwoLetterISOLanguageName) ?? AppLanguage.En;

    public static AppLanguage FromEnvironment() =>
        Resolve(CultureInfo.CurrentUICulture, Environment.GetEnvironmentVariable(EnvironmentVariable));

    private static AppLanguage? TryParse(string? code)
    {
        var language = code?.Split('-', '_')[0].Trim().ToLowerInvariant();
        return language switch
        {
            "es" => AppLanguage.Es,
            "en" => AppLanguage.En,
            "pt" => AppLanguage.Pt,
            _ => null,
        };
    }
}
