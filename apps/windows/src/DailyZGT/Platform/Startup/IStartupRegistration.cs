namespace DailyZGT.Platform;

public enum StartupState
{
    Off,
    On,
    OnButDisabledByUser,
}

public sealed class StartupException(string message, Exception? inner = null) : Exception(message, inner);

public interface IStartupRegistration
{
    StartupState State { get; }

    void Enable();

    void Disable();
}

public static class StartupApproved
{
    public static bool IsDisabled(byte[]? data) => data is { Length: > 0 } && (data[0] & 1) == 1;
}
