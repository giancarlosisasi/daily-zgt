namespace DailyZGT.Platform;

public interface IAnimationSetting : IDisposable
{
    bool AnimationsEnabled { get; }

    event EventHandler? Changed;

    void Start();
}
