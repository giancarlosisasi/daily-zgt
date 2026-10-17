namespace DailyZGT.Core.Domain;

// F06. The limit blocks only an add or a move into Hoy. Undo, Regresar and the daily copy never check it.
public static class TodayLimit
{
    public const int MaxOpen = 5;
    public const string Message = "Hoy ya tiene 5 prioridades abiertas.";

    public static bool BlocksAdd(bool isOn, int openCount) => isOn && openCount >= MaxOpen;
}
