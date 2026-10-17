namespace DailyZGT.Platform;

public sealed record ToastRequest(string Id, string Title, string Body, DateTime FireAt, string? PriorityId);

public enum ToastAction
{
    Open,
    Snooze,
}

public sealed record ToastActivation(string AlertId, string? PriorityId, ToastAction Action);

public enum ToastAvailability
{
    Enabled,
    Disabled,
    DisabledByPolicy,
}

public sealed class ToastException(string message, Exception? inner = null) : Exception(message, inner);
