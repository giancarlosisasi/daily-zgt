namespace DailyZGT.Shell;

// What a launch of the exe asks for, from its own command line or from a second launch that handed its
// arguments over. --toast carries the arguments of a toast that a second launch was started for.
public sealed record LaunchRequest(bool ShowPanel, bool ShowCapture, string? ToastArguments)
{
    public const string ShowPanelFlag = "--show-panel";
    public const string ShowCaptureFlag = "--show-capture";
    public const string ToastFlag = "--toast";

    public bool AsksForAnything => ShowPanel || ShowCapture || ToastArguments is not null;

    public static LaunchRequest Parse(IReadOnlyList<string> args)
    {
        var toast = args.ToList().IndexOf(ToastFlag);
        return new LaunchRequest(
            args.Contains(ShowPanelFlag),
            args.Contains(ShowCaptureFlag),
            toast >= 0 && toast + 1 < args.Count ? args[toast + 1] : null);
    }

    public static IReadOnlyList<string> WithToast(IReadOnlyList<string> args, string toastArguments) =>
        [.. args, ToastFlag, toastArguments];
}
