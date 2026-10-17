namespace DailyZGT.Core.Alerts;

public enum AlertAction { Open, Snooze }

// What the user did with a toast. PriorityId is null for the test alert.
public sealed record AlertResponse(string AlertId, string? PriorityId, AlertAction Action);

public sealed class AlertSystemException(string message, Exception? inner = null) : Exception(message, inner);

// The notification system as the coordinator sees it. The Windows adapter sits over the toast center, a fake
// sits under the tests. Calls come from the UI thread and block until the system took them.
public interface IAlertSystem
{
    // Windows reports the app's notifications as enabled or disabled. There is no prompt to ask for.
    AlertAuthorization Authorization { get; }

    // The user clicked a toast or one of its buttons. Raised on the UI thread.
    event EventHandler<AlertResponse>? Responded;

    // Hooks the activation source. Called once, on the UI thread.
    void Start();

    // The toasts waiting to fire, with the id, text and fire time they were scheduled with.
    IReadOnlyList<AlertRequest> Pending();

    // Ids of the toasts that fired and still sit in the action center. Windows sends no event when a
    // scheduled toast fires. The rows move to delivered by their fire time (the coordinator wakes one second
    // after it), and this list tells the coordinator which toast Windows already showed.
    IReadOnlyList<string> DeliveredIds();

    // Replaces a pending toast with the same id. A fire time within AlertCoordinator.ShownAtOnce shows the
    // toast at once.
    void Schedule(AlertRequest request);

    void RemovePending(IEnumerable<string> ids);

    void RemoveDelivered(IEnumerable<string> ids);
}
