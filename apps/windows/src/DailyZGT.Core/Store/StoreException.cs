namespace DailyZGT.Core.Store;

// Every failure of the store: SQLite errors, an unreadable file, or an id that is no longer in the database.
// The UI shows one message for all of them ("No se pudo guardar el cambio.").
public sealed class StoreException(string message, Exception? inner = null) : Exception(message, inner);
