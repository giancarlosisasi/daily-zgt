namespace DailyZGT.Platform;

public interface ISingleInstance : IDisposable
{
    bool IsPrimary { get; }

    event EventHandler<IReadOnlyList<string>>? ArgumentsReceived;

    void StartListening();

    bool ForwardToPrimary(IReadOnlyList<string> arguments);
}
