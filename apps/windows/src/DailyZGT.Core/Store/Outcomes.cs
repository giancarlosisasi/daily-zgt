using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Store;

public abstract record AddOutcome
{
    private AddOutcome() { }

    public sealed record Added(Priority Priority) : AddOutcome;

    // F05, F17: a blank title adds nothing and shows no message.
    public sealed record EmptyTitle : AddOutcome;

    // F06: the form or the capture window keeps its text and shows TodayLimit.Message.
    public sealed record BlockedByTodayLimit : AddOutcome;
}

public abstract record MoveOutcome
{
    private MoveOutcome() { }

    public sealed record Moved(Priority Priority) : MoveOutcome;

    public sealed record BlockedByTodayLimit : MoveOutcome;
}
