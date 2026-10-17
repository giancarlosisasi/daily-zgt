namespace DailyZGT.Core.Rules;

public static class HistoryCopy
{
    public const string Title = "Historial";
    public const string Back = "Volver a Hechas";
    public const string Empty = "Nada en el historial.";
}

public static class PriorityListCopy
{
    public const string EmptyDone = "Todo listo en esta lista";
    public const string EmptyOpen = "Nada pendiente en esta lista.";
    public const string SaveFailed = "No se pudo guardar el cambio.";
    public const string NoteSaveFailed = "No se pudo guardar la nota.";

    // F08
    public static string DoneHeader(int count) => $"Hechas ({count})";

    // F07. The bar clips a long title with an ellipsis, so the string keeps the whole title.
    public static string UndoLine(string title) => $"Hecha: {title}";
}
