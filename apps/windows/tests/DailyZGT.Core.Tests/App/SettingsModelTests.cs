using DailyZGT.Core.App;

namespace DailyZGT.Core.Tests.App;

public sealed class StartupSettingsTests
{
    private readonly FakeStartupService _service = new();

    private StartupSettings Model(StartupStatus status)
    {
        _service.State = status;
        return new StartupSettings(_service);
    }

    [Theory]
    [InlineData(StartupStatus.Off, false, false)]
    [InlineData(StartupStatus.On, true, false)]
    [InlineData(StartupStatus.OnButDisabledByUser, true, true)]
    public void EachStatusSetsTheSwitchAndTheApprovalLine(StartupStatus status, bool isOn, bool needsApproval)
    {
        var settings = Model(status);

        Assert.Equal(status, settings.Status);
        Assert.Equal(isOn, settings.IsOn);
        Assert.Equal(needsApproval, settings.NeedsApproval);
        Assert.False(settings.ChangeFailed);
    }

    [Fact]
    public void TheSwitchOnEnablesTheApp()
    {
        var settings = Model(StartupStatus.Off);

        settings.Set(true);

        Assert.Equal(1, _service.EnableCalls);
        Assert.Equal(0, _service.DisableCalls);
        Assert.True(settings.IsOn);
    }

    [Fact]
    public void TheSwitchOffDisablesTheApp()
    {
        var settings = Model(StartupStatus.On);

        settings.Set(false);

        Assert.Equal(1, _service.DisableCalls);
        Assert.Equal(0, _service.EnableCalls);
        Assert.False(settings.IsOn);
    }

    [Fact]
    public void ASwitchToTheStateThatIsAlreadySetCallsNothing()
    {
        var settings = Model(StartupStatus.On);

        settings.Set(true);

        Assert.Equal(0, _service.EnableCalls);
        Assert.Equal(0, _service.DisableCalls);
    }

    [Fact]
    public void AFailedEnableKeepsTheSwitchOffAndShowsTheError()
    {
        var settings = Model(StartupStatus.Off);
        _service.EnableFails = true;

        settings.Set(true);

        Assert.True(settings.ChangeFailed);
        Assert.False(settings.IsOn);
    }

    [Fact]
    public void AFailedDisableKeepsTheSwitchOnAndShowsTheError()
    {
        var settings = Model(StartupStatus.On);
        _service.DisableFails = true;

        settings.Set(false);

        Assert.True(settings.ChangeFailed);
        Assert.True(settings.IsOn);
    }

    [Fact]
    public void ALaterSuccessClearsTheError()
    {
        var settings = Model(StartupStatus.Off);
        _service.EnableFails = true;
        settings.Set(true);

        _service.EnableFails = false;
        settings.Set(true);

        Assert.False(settings.ChangeFailed);
        Assert.True(settings.IsOn);
    }

    [Fact]
    public void TheSwitchOffWhileDisabledInSettingsRemovesTheApp()
    {
        var settings = Model(StartupStatus.OnButDisabledByUser);

        settings.Set(false);

        Assert.Equal(1, _service.DisableCalls);
        Assert.False(settings.NeedsApproval);
        Assert.False(settings.IsOn);
    }

    [Fact]
    public void ASwitchReadsTheSystemBeforeItActs()
    {
        var settings = Model(StartupStatus.Off);
        _service.State = StartupStatus.On;

        settings.Set(true);

        Assert.Equal(0, _service.EnableCalls);
        Assert.True(settings.IsOn);
    }

    [Fact]
    public void ARefreshShowsAChangeMadeInWindowsSettingsAndKeepsTheError()
    {
        var settings = Model(StartupStatus.Off);
        _service.EnableFails = true;
        settings.Set(true);
        _service.State = StartupStatus.OnButDisabledByUser;

        settings.Refresh();

        Assert.True(settings.NeedsApproval);
        Assert.True(settings.ChangeFailed);
    }

    [Fact]
    public void OpeningTheSettingsReadsTheStatusAndClearsTheError()
    {
        var settings = Model(StartupStatus.Off);
        _service.EnableFails = true;
        settings.Set(true);
        _service.State = StartupStatus.On;

        settings.SettingsDidOpen();

        Assert.True(settings.IsOn);
        Assert.False(settings.ChangeFailed);
    }

    [Fact]
    public void TheDerivedPropertiesAreRaisedWithTheStatus()
    {
        var settings = Model(StartupStatus.Off);
        var raised = new List<string?>();
        settings.PropertyChanged += (_, e) => raised.Add(e.PropertyName);

        settings.Set(true);

        Assert.Contains(nameof(StartupSettings.IsOn), raised);
        Assert.Contains(nameof(StartupSettings.NeedsApproval), raised);
    }
}

public sealed class ShortcutSettingsTests
{
    private static readonly CaptureShortcut CtrlShiftK = new(ShortcutModifiers.Control | ShortcutModifiers.Shift, 'K');

    private readonly FakeHotkey _hotkey = new();

    [Fact]
    public void StartsWithTheSavedShortcut()
    {
        var settings = new ShortcutSettings(_hotkey);

        Assert.Equal(FakeHotkey.Default, settings.Shortcut);
        Assert.True(settings.IsSet);
        Assert.Equal(ShortcutRecording.Idle, settings.Recording);
        Assert.Null(settings.Failure);
    }

    [Fact]
    public void TheStartRegistersTheHotkeyAndShowsAShortcutThatIsTaken()
    {
        var settings = new ShortcutSettings(_hotkey);
        _hotkey.StartFailure = ShortcutFailure.InUse;

        settings.Start();

        Assert.Equal(1, _hotkey.StartCalls);
        Assert.Equal(ShortcutFailure.InUse, settings.Failure);
    }

    [Fact]
    public void RecordingANewShortcutSavesItAndStops()
    {
        var settings = new ShortcutSettings(_hotkey);

        settings.StartRecording();
        Assert.Equal(ShortcutRecording.Recording, settings.Recording);
        settings.Record(CtrlShiftK);

        Assert.Equal(CtrlShiftK, settings.Shortcut);
        Assert.Equal(CtrlShiftK, _hotkey.Current);
        Assert.Equal(ShortcutRecording.Idle, settings.Recording);
    }

    [Fact]
    public void ATakenShortcutKeepsTheOldOneAndKeepsRecording()
    {
        var settings = new ShortcutSettings(_hotkey);
        settings.StartRecording();
        _hotkey.SetFailure = ShortcutFailure.InUse;

        settings.Record(CtrlShiftK);

        Assert.Equal(FakeHotkey.Default, settings.Shortcut);
        Assert.Equal(ShortcutFailure.InUse, settings.Failure);
        Assert.Equal(ShortcutRecording.Recording, settings.Recording);

        _hotkey.SetFailure = null;
        settings.Record(CtrlShiftK);
        Assert.Null(settings.Failure);
        Assert.Equal(CtrlShiftK, settings.Shortcut);
    }

    [Fact]
    public void EscapeStopsRecordingWithNoChange()
    {
        var settings = new ShortcutSettings(_hotkey);
        settings.StartRecording();
        _hotkey.SetFailure = ShortcutFailure.InvalidShortcut;
        settings.Record(new CaptureShortcut(ShortcutModifiers.None, 'K'));

        settings.CancelRecording();

        Assert.Equal(ShortcutRecording.Idle, settings.Recording);
        Assert.Null(settings.Failure);
        Assert.Equal(FakeHotkey.Default, settings.Shortcut);
    }

    [Fact]
    public void ClearingRemovesTheShortcut()
    {
        var settings = new ShortcutSettings(_hotkey);
        settings.StartRecording();
        var raised = new List<string?>();
        settings.PropertyChanged += (_, e) => raised.Add(e.PropertyName);

        settings.Clear();

        Assert.Null(settings.Shortcut);
        Assert.False(settings.IsSet);
        Assert.Null(_hotkey.Current);
        Assert.Equal(ShortcutRecording.Idle, settings.Recording);
        Assert.Contains(nameof(ShortcutSettings.IsSet), raised);
    }

    [Fact]
    public void OpeningTheSettingsReadsTheShortcutAndStopsRecording()
    {
        var settings = new ShortcutSettings(_hotkey);
        settings.StartRecording();
        _hotkey.Current = CtrlShiftK;

        settings.SettingsDidOpen();

        Assert.Equal(CtrlShiftK, settings.Shortcut);
        Assert.Equal(ShortcutRecording.Idle, settings.Recording);
    }
}
