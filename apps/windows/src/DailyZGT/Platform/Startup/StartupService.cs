using DailyZGT.Core.App;

namespace DailyZGT.Platform;

// The Run key registration as Core's StartupSettings sees it.
public sealed class StartupService(IStartupRegistration registration) : IStartupService
{
    public StartupStatus State => (StartupStatus)registration.State;

    public void Enable() => Change(registration.Enable);

    public void Disable() => Change(registration.Disable);

    private static void Change(Action change)
    {
        try
        {
            change();
        }
        catch (StartupException error)
        {
            throw new StartupChangeException(error.Message, error);
        }
    }
}
