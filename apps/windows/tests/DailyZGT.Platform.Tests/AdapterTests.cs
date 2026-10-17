using DailyZGT.Core.App;
using DailyZGT.Core.Store;

namespace DailyZGT.Platform.Tests;

public class AdapterTests
{
    [Theory]
    [InlineData(StartupState.Off, StartupStatus.Off)]
    [InlineData(StartupState.On, StartupStatus.On)]
    [InlineData(StartupState.OnButDisabledByUser, StartupStatus.OnButDisabledByUser)]
    public void Startup_state_reaches_the_settings_as_it_is(StartupState state, StartupStatus status)
    {
        Assert.Equal(status, new StartupService(new FakeRegistration { State = state }).State);
    }

    [Fact]
    public void A_refused_startup_change_shows_the_error_line()
    {
        var settings = new StartupSettings(new StartupService(new FakeRegistration { Fails = true }));

        settings.Set(true);

        Assert.True(settings.ChangeFailed);
        Assert.False(settings.IsOn);
    }

    [Fact]
    public void A_shortcut_Windows_holds_is_reported_as_taken_and_the_old_one_stays()
    {
        var hotkey = new FakeGlobalHotkey { Refuse = HotkeyFailure.InUse };
        var settings = new ShortcutSettings(new CaptureHotkey(hotkey));
        settings.StartRecording();

        settings.Record(new CaptureShortcut(ShortcutModifiers.Control, 'K'));

        Assert.Equal(ShortcutFailure.InUse, settings.Failure);
        Assert.Equal(ShortcutRecording.Recording, settings.Recording);
        Assert.Equal(CaptureHotkey.ToCore(HotkeyShortcut.Default), settings.Shortcut);
    }

    [Fact]
    public void A_recorded_shortcut_is_set_with_the_same_keys()
    {
        var hotkey = new FakeGlobalHotkey();
        var settings = new ShortcutSettings(new CaptureHotkey(hotkey));
        var keys = new CaptureShortcut(ShortcutModifiers.Control | ShortcutModifiers.Win, 0x78);

        settings.StartRecording();
        settings.Record(keys);

        Assert.Equal(new HotkeyShortcut(HotkeyModifiers.Control | HotkeyModifiers.Win, 0x78), hotkey.Current);
        Assert.Equal(keys, settings.Shortcut);
        Assert.Equal(ShortcutRecording.Idle, settings.Recording);
    }

    [Fact]
    public void The_hotkey_opens_and_closes_the_capture_window()
    {
        var hotkey = new FakeGlobalHotkey();
        using var store = AppStore.OpenInMemory(TimeProvider.System);
        using var capture = new CaptureModel(store);
        capture.Attach(new CaptureHotkey(hotkey));

        hotkey.Press();
        Assert.True(capture.IsOpen);

        hotkey.Press();
        Assert.False(capture.IsOpen);
    }

    [Fact]
    public void A_shortcut_held_at_start_is_reported()
    {
        var settings = new ShortcutSettings(new CaptureHotkey(new FakeGlobalHotkey { StartFailure = HotkeyFailure.InUse }));

        settings.Start();

        Assert.Equal(ShortcutFailure.InUse, settings.Failure);
    }

    private sealed class FakeRegistration : IStartupRegistration
    {
        public StartupState State { get; set; }

        public bool Fails { get; init; }

        public void Enable()
        {
            if (Fails)
            {
                throw new StartupException("refused");
            }

            State = StartupState.On;
        }

        public void Disable() => State = StartupState.Off;
    }

    private sealed class FakeGlobalHotkey : IGlobalHotkey
    {
        public HotkeyShortcut? Current { get; private set; } = HotkeyShortcut.Default;

        public bool IsActive => Current is not null;

        public HotkeyFailure? Refuse { get; init; }

        public HotkeyFailure? StartFailure { get; init; }

        public event EventHandler? Pressed;

        public HotkeyFailure? Start() => StartFailure;

        public void Set(HotkeyShortcut shortcut)
        {
            if (Refuse is { } failure)
            {
                throw new HotkeyException(failure, "refused");
            }

            Current = shortcut;
        }

        public void Clear() => Current = null;

        public void Press() => Pressed?.Invoke(this, EventArgs.Empty);

        public void Dispose()
        {
        }
    }
}
