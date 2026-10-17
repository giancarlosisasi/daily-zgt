using DailyZGT.Core.Alerts;

namespace DailyZGT.Platform;

// The Windows side of IAlertSystem: the toast center, with its types turned into the Core ones and its
// failures turned into AlertSystemException.
public sealed class ToastAlertSystem : IAlertSystem, IDisposable
{
    private readonly IToastCenter center;

    public ToastAlertSystem(IToastCenter center)
    {
        this.center = center;
        center.Activated += OnActivated;
    }

    public event EventHandler<AlertResponse>? Responded;

    public AlertAuthorization Authorization =>
        Guard(() => center.Availability == ToastAvailability.Enabled ? AlertAuthorization.Authorized : AlertAuthorization.Denied);

    public void Start() => Guard(center.Start);

    public IReadOnlyList<AlertRequest> Pending() => Guard(() => center
        .Pending()
        .Select(toast => new AlertRequest(toast.Id, toast.Title, toast.Body, toast.FireAt, toast.PriorityId))
        .ToList());

    public IReadOnlyList<string> DeliveredIds() => Guard(center.DeliveredIds);

    public void Schedule(AlertRequest request) => Guard(() => center.Schedule(
        new ToastRequest(request.Id, request.Title, request.Body, request.FireAt, request.PriorityId)));

    public void RemovePending(IEnumerable<string> ids) => Guard(() => center.RemovePending(ids));

    public void RemoveDelivered(IEnumerable<string> ids) => Guard(() => center.RemoveDelivered(ids));

    public void Dispose() => center.Activated -= OnActivated;

    private void OnActivated(object? sender, ToastActivation activation) =>
        Responded?.Invoke(
            this,
            new AlertResponse(
                activation.AlertId,
                activation.PriorityId,
                activation.Action == ToastAction.Snooze ? AlertAction.Snooze : AlertAction.Open));

    private static T Guard<T>(Func<T> work)
    {
        try
        {
            return work();
        }
        catch (ToastException error)
        {
            throw new AlertSystemException(error.Message, error);
        }
    }

    private static void Guard(Action work) => Guard(() =>
    {
        work();
        return true;
    });
}
