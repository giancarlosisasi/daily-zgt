namespace DailyZGT.Platform;

public interface IToastCenter : IDisposable
{
    ToastAvailability Availability { get; }

    event EventHandler<ToastActivation>? Activated;

    void Start();

    void Show(ToastRequest request);

    void Schedule(ToastRequest request);

    IReadOnlyList<ToastRequest> Pending();

    IReadOnlyList<string> DeliveredIds();

    void RemovePending(IEnumerable<string> ids);

    void RemoveDelivered(IEnumerable<string> ids);
}
