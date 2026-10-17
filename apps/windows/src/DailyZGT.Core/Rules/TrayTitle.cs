using System.Globalization;

namespace DailyZGT.Core.Rules;

// F01. The title of the next priority in the tray tooltip.
public static class TrayTitle
{
    public const int MaxLength = 24;
    public const string Ellipsis = "…";

    private static readonly char[] Newlines = ['\n', '\r', '\v', '\f', (char)0x0085, (char)0x2028, (char)0x2029];

    public static string? Text(string? title)
    {
        if (title is null)
        {
            return null;
        }

        var clean = string.Join(' ', title.Split(Newlines, StringSplitOptions.RemoveEmptyEntries)).Trim();
        if (clean.Length == 0)
        {
            return null;
        }

        var info = new StringInfo(clean);
        if (info.LengthInTextElements <= MaxLength)
        {
            return clean;
        }

        var head = info.SubstringByTextElements(0, MaxLength - 1).TrimEnd();
        return head + Ellipsis;
    }
}
