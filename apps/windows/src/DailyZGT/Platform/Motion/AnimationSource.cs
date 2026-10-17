using DailyZGT.Core.App;

namespace DailyZGT.Platform;

// The Windows "Animation effects" setting as Core's MotionPolicy sees it.
public sealed class AnimationSource : IAnimationSource
{
    private readonly IAnimationSetting setting;

    public AnimationSource(IAnimationSetting setting)
    {
        this.setting = setting;
        setting.Changed += (_, _) => Changed?.Invoke(this, EventArgs.Empty);
    }

    public bool AnimationsEnabled => setting.AnimationsEnabled;

    public event EventHandler? Changed;
}
