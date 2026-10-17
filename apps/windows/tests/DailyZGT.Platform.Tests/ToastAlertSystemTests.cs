using DailyZGT.Core.Alerts;
using DailyZGT.Platform;

namespace DailyZGT.Platform.Tests;

public class ToastAlertSystemTests
{
    private sealed class FakeToastCenter : IToastCenter
    {
        public ToastAvailability Availability { get; set; } = ToastAvailability.Enabled;

        public List<ToastRequest> Scheduled { get; } = [];

        public List<string> RemovedPending { get; } = [];

        public List<string> RemovedDelivered { get; } = [];

        public List<string> Delivered { get; } = [];

        public int Starts { get; private set; }

        public bool Fails { get; set; }

        public event EventHandler<ToastActivation>? Activated;

        public bool HasListener => Activated is not null;

        public void Raise(ToastActivation activation) => Activated?.Invoke(this, activation);

        public void Start() => Starts++;

        public void Show(ToastRequest request) => throw new NotSupportedException();

        public void Schedule(ToastRequest request)
        {
            Fail();
            Scheduled.Add(request);
        }

        public IReadOnlyList<ToastRequest> Pending()
        {
            Fail();
            return Scheduled;
        }

        public IReadOnlyList<string> DeliveredIds() => Delivered;

        public void RemovePending(IEnumerable<string> ids) => RemovedPending.AddRange(ids);

        public void RemoveDelivered(IEnumerable<string> ids) => RemovedDelivered.AddRange(ids);

        public void Dispose()
        {
        }

        private void Fail()
        {
            if (Fails)
            {
                throw new ToastException("Windows toast notifications failed.");
            }
        }
    }

    [Theory]
    [InlineData(ToastAvailability.Enabled, AlertAuthorization.Authorized)]
    [InlineData(ToastAvailability.Disabled, AlertAuthorization.Denied)]
    [InlineData(ToastAvailability.DisabledByPolicy, AlertAuthorization.Denied)]
    public void WindowsAvailabilityMapsToTheAuthorization(ToastAvailability availability, AlertAuthorization expected)
    {
        using var system = new ToastAlertSystem(new FakeToastCenter { Availability = availability });

        Assert.Equal(expected, system.Authorization);
    }

    [Fact]
    public void ARequestGoesToTheCenterAndComesBackAsPending()
    {
        var center = new FakeToastCenter();
        using var system = new ToastAlertSystem(center);
        var request = new AlertRequest("a1", "Vence en 30 min", "Terminar el brief", new DateTime(2026, 10, 12, 11, 30, 0), "p1");

        system.Schedule(request);

        Assert.Equal(new ToastRequest("a1", "Vence en 30 min", "Terminar el brief", request.FireAt, "p1"), Assert.Single(center.Scheduled));
        Assert.Equal(request, Assert.Single(system.Pending()));
    }

    [Fact]
    public void RemovalsAndDeliveredIdsPassThrough()
    {
        var center = new FakeToastCenter { Delivered = { "a1", "a2" } };
        using var system = new ToastAlertSystem(center);

        system.RemovePending(["a1"]);
        system.RemoveDelivered(["a2"]);

        Assert.Equal(["a1"], center.RemovedPending);
        Assert.Equal(["a2"], center.RemovedDelivered);
        Assert.Equal(["a1", "a2"], system.DeliveredIds());
    }

    [Fact]
    public void StartStartsTheCenter()
    {
        var center = new FakeToastCenter();
        using var system = new ToastAlertSystem(center);

        system.Start();

        Assert.Equal(1, center.Starts);
    }

    [Theory]
    [InlineData(ToastAction.Open, AlertAction.Open, "p1")]
    [InlineData(ToastAction.Snooze, AlertAction.Snooze, "p1")]
    [InlineData(ToastAction.Open, AlertAction.Open, null)]
    public void AnActivationBecomesAResponse(ToastAction action, AlertAction expected, string? priority)
    {
        var center = new FakeToastCenter();
        using var system = new ToastAlertSystem(center);
        var responses = new List<AlertResponse>();
        system.Responded += (_, response) => responses.Add(response);

        center.Raise(new ToastActivation("a1", priority, action));

        Assert.Equal(new AlertResponse("a1", priority, expected), Assert.Single(responses));
    }

    [Fact]
    public void DisposeStopsListeningToTheCenter()
    {
        var center = new FakeToastCenter();
        var system = new ToastAlertSystem(center);

        system.Dispose();

        Assert.False(center.HasListener);
    }

    [Fact]
    public void AToastFailureBecomesAnAlertSystemFailure()
    {
        var center = new FakeToastCenter { Fails = true };
        using var system = new ToastAlertSystem(center);

        var error = Assert.Throws<AlertSystemException>(() => system.Pending());
        Assert.IsType<ToastException>(error.InnerException);
        Assert.Throws<AlertSystemException>(() =>
            system.Schedule(new AlertRequest("a1", "t", "b", new DateTime(2026, 10, 12, 11, 30, 0), null)));
    }
}
