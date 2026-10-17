namespace DailyZGT.Core.Domain;

// F06. The limit blocks only an add or a move into Hoy. Undo, Regresar and the daily copy never check it.
// The message for the user is Texts.TodayLimitMessage.
public static class TodayLimit
{
    public const int MaxOpen = 5;

    public static bool BlocksAdd(bool isOn, int openCount) => isOn && openCount >= MaxOpen;
}
