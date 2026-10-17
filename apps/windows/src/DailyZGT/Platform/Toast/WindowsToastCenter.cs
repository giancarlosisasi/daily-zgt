using CommunityToolkit.WinUI.Notifications;
using Windows.UI.Notifications;

namespace DailyZGT.Platform;

public sealed class WindowsToastCenter : IToastCenter
{
    public const string AlertKey = "alert_id";
    public const string PriorityKey = "priority_id";
    public const string ActionKey = "action";
    public const string OpenAction = "open";
    public const string SnoozeAction = "snooze";
    public const string OpenLabel = "Abrir";
    public const string SnoozeLabel = "Posponer 15 min";
    public const string Group = "alerts";

    private static readonly TimeSpan MinimumLead = TimeSpan.FromSeconds(1);

    private readonly TimeProvider time;
    private SynchronizationContext? context;
    private bool started;

    public WindowsToastCenter(TimeProvider? time = null)
    {
        this.time = time ?? TimeProvider.System;
    }

    public event EventHandler<ToastActivation>? Activated;

    public ToastAvailability Availability => Guard(() => Notifier().Setting switch
    {
        NotificationSetting.Enabled => ToastAvailability.Enabled,
        NotificationSetting.DisabledByGroupPolicy => ToastAvailability.DisabledByPolicy,
        _ => ToastAvailability.Disabled,
    });

    public void Start()
    {
        if (started)
        {
            return;
        }

        started = true;
        context = SynchronizationContext.Current;
        ToastNotificationManagerCompat.OnActivated += OnCompatActivated;
    }

    public void Show(ToastRequest request) => Guard(() =>
    {
        var toast = new ToastNotification(Content(request).GetXml())
        {
            Tag = request.Id,
            Group = Group,
        };
        Notifier().Show(toast);
    });

    public void Schedule(ToastRequest request) => Guard(() =>
    {
        RemovePending([request.Id]);
        var fireAt = new DateTimeOffset(DateTime.SpecifyKind(request.FireAt, DateTimeKind.Local));
        if (fireAt - time.GetLocalNow() < MinimumLead)
        {
            Show(request);
            return;
        }

        var toast = new ScheduledToastNotification(Content(request).GetXml(), fireAt)
        {
            Tag = request.Id,
            Group = Group,
        };
        Notifier().AddToSchedule(toast);
    });

    public IReadOnlyList<ToastRequest> Pending() => Guard(() => Notifier()
        .GetScheduledToastNotifications()
        .Where(t => t.Group == Group)
        .Select(Describe)
        .ToList());

    public IReadOnlyList<string> DeliveredIds() => Guard(() => ToastNotificationManagerCompat.History
        .GetHistory()
        .Where(t => t.Group == Group)
        .Select(t => t.Tag)
        .ToList());

    public void RemovePending(IEnumerable<string> ids) => Guard(() =>
    {
        var wanted = ids.ToHashSet();
        var notifier = Notifier();
        foreach (var scheduled in notifier.GetScheduledToastNotifications().Where(t => t.Group == Group && wanted.Contains(t.Tag)))
        {
            notifier.RemoveFromSchedule(scheduled);
        }
    });

    public void RemoveDelivered(IEnumerable<string> ids) => Guard(() =>
    {
        foreach (var id in ids)
        {
            ToastNotificationManagerCompat.History.Remove(id, Group);
        }
    });

    public void Dispose()
    {
        if (started)
        {
            ToastNotificationManagerCompat.OnActivated -= OnCompatActivated;
            started = false;
        }
    }

    internal static ToastActivation? ParseActivation(string arguments)
    {
        var parsed = ToastArguments.Parse(arguments);
        if (!parsed.TryGetValue(AlertKey, out var alertId))
        {
            return null;
        }

        parsed.TryGetValue(PriorityKey, out var priorityId);
        parsed.TryGetValue(ActionKey, out var action);
        return new ToastActivation(
            alertId,
            string.IsNullOrEmpty(priorityId) ? null : priorityId,
            action == SnoozeAction ? ToastAction.Snooze : ToastAction.Open);
    }

    private static ToastNotifierCompat Notifier() => ToastNotificationManagerCompat.CreateToastNotifier();

    private static ToastContent Content(ToastRequest request)
    {
        var builder = new ToastContentBuilder()
            .AddText(request.Title)
            .AddText(request.Body)
            .AddArgument(AlertKey, request.Id);
        if (request.PriorityId is { } priorityId)
        {
            builder.AddArgument(PriorityKey, priorityId);
        }

        builder.AddButton(Button(OpenLabel, OpenAction, request, background: false));
        builder.AddButton(Button(SnoozeLabel, SnoozeAction, request, background: true));
        return builder.GetToastContent();
    }

    private static ToastButton Button(string label, string action, ToastRequest request, bool background)
    {
        var button = new ToastButton().SetContent(label).AddArgument(AlertKey, request.Id).AddArgument(ActionKey, action);
        if (request.PriorityId is { } priorityId)
        {
            button.AddArgument(PriorityKey, priorityId);
        }

        return background ? button.SetBackgroundActivation() : button;
    }

    private static ToastRequest Describe(ScheduledToastNotification toast)
    {
        var texts = toast.Content.GetElementsByTagName("text");
        var launch = toast.Content.DocumentElement.GetAttribute("launch");
        ToastArguments.Parse(launch).TryGetValue(PriorityKey, out var priorityId);
        return new ToastRequest(
            toast.Tag,
            texts.Count > 0 ? texts[0].InnerText : string.Empty,
            texts.Count > 1 ? texts[1].InnerText : string.Empty,
            toast.DeliveryTime.LocalDateTime,
            string.IsNullOrEmpty(priorityId) ? null : priorityId);
    }

    private void OnCompatActivated(ToastNotificationActivatedEventArgsCompat args)
    {
        if (ParseActivation(args.Argument) is not { } activation)
        {
            return;
        }

        if (context is { } ui)
        {
            ui.Post(_ => Activated?.Invoke(this, activation), null);
        }
        else
        {
            Activated?.Invoke(this, activation);
        }
    }

    private static T Guard<T>(Func<T> work)
    {
        try
        {
            return work();
        }
        catch (Exception error) when (error is not ToastException)
        {
            throw new ToastException("Windows toast notifications failed.", error);
        }
    }

    private static void Guard(Action work) => Guard(() =>
    {
        work();
        return true;
    });
}
