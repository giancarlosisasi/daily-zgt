namespace DailyZGT.Core.App;

// The Windows "Animation effects" setting, as the app's IAnimationSetting reports it.
public interface IAnimationSource
{
    bool AnimationsEnabled { get; }

    event EventHandler? Changed;
}

// F22. The motion decisions that change what the models do. The views read every other duration from
// TeclaTokens and skip their animations through Theme.Motion.
public sealed class MotionPolicy : ObservableModel, IDisposable
{
    private readonly IAnimationSource _source;
    private readonly TimeSpan _rowLeave;
    private bool _isReduced;

    // rowLeave is the Tecla "slow" duration: the row slides out for that long before the store write.
    public MotionPolicy(IAnimationSource source, TimeSpan rowLeave)
    {
        _source = source;
        _rowLeave = rowLeave;
        _isReduced = !source.AnimationsEnabled;
        source.Changed += OnSourceChanged;
    }

    public bool IsReduced
    {
        get => _isReduced;
        private set
        {
            if (Set(ref _isReduced, value))
            {
                Raise(nameof(Animates), nameof(LeaveDelay));
            }
        }
    }

    public bool Animates => !IsReduced;

    // F07. With reduced motion the row that is marked done goes at once.
    public TimeSpan LeaveDelay => IsReduced ? TimeSpan.Zero : _rowLeave;

    public void Dispose() => _source.Changed -= OnSourceChanged;

    private void OnSourceChanged(object? sender, EventArgs e) => IsReduced = !_source.AnimationsEnabled;
}
