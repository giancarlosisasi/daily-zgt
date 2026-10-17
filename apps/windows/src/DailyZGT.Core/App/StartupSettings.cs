namespace DailyZGT.Core.App;

// F18. Mirrors DailyZGT.Platform.StartupState. OnButDisabledByUser: the Run entry exists, but the person
// turned the app off in Settings > Apps > Startup.
public enum StartupStatus { Off, On, OnButDisabledByUser }

public sealed class StartupChangeException(string message, Exception? inner = null) : Exception(message, inner);

// The app adapts DailyZGT.Platform.IStartupRegistration to this. Enable and Disable throw
// StartupChangeException when Windows does not accept the change.
public interface IStartupService
{
    StartupStatus State { get; }

    void Enable();

    void Disable();
}

// F18. "Abrir al iniciar sesión". The switch reads the system before it acts. A switch that is on but
// disabled in Settings shows the approval line, and turning it off removes the app from the startup list.
// A failed change shows the error line until the settings open again or a later change works.
public sealed class StartupSettings : ObservableModel
{
    private readonly IStartupService _service;
    private StartupStatus _status;
    private bool _changeFailed;

    public StartupSettings(IStartupService service)
    {
        _service = service;
        _status = service.State;
    }

    public StartupStatus Status
    {
        get => _status;
        private set
        {
            if (Set(ref _status, value))
            {
                Raise(nameof(IsOn), nameof(NeedsApproval));
            }
        }
    }

    public bool IsOn => Status != StartupStatus.Off;

    // "Falta tu aprobación en Configuración." with "Abrir ajustes".
    public bool NeedsApproval => Status == StartupStatus.OnButDisabledByUser;

    // "Windows no aceptó el cambio."
    public bool ChangeFailed
    {
        get => _changeFailed;
        private set => Set(ref _changeFailed, value);
    }

    // The app calls this when it comes to the front.
    public void Refresh() => Status = _service.State;

    public void SettingsDidOpen()
    {
        ChangeFailed = false;
        Refresh();
    }

    public void Set(bool on)
    {
        Refresh();
        if (on == IsOn)
        {
            return;
        }
        try
        {
            if (on)
            {
                _service.Enable();
            }
            else
            {
                _service.Disable();
            }
            ChangeFailed = false;
        }
        catch (StartupChangeException)
        {
            ChangeFailed = true;
        }
        Refresh();
    }
}
