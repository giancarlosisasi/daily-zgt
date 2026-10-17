using System.Text.Json;
using System.Text.Json.Serialization;
using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Store;

// app_state values are JSON text, as the macOS app writes them: true, "notes", "today".
public sealed record AppStateKey<T>(string Name, T DefaultValue)
{
    private static readonly JsonSerializerOptions Json = new()
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase, allowIntegerValues: false) },
    };

    internal string Encode(T value) => JsonSerializer.Serialize(value, Json);

    internal T Decode(string? text)
    {
        if (text is null)
        {
            return DefaultValue;
        }
        try
        {
            var value = JsonSerializer.Deserialize<T>(text, Json);
            return value is null && DefaultValue is not null ? DefaultValue : value!;
        }
        catch (JsonException)
        {
            return DefaultValue;
        }
    }
}

public static class AppStateKeys
{
    public static readonly AppStateKey<PanelTab> OpenTab = new("open_tab", PanelTab.Priorities);
    public static readonly AppStateKey<PriorityList> OpenScope = new("open_scope", PriorityList.Today);
    public static readonly AppStateKey<bool> DoneOpen = new("done_open", false);
    public static readonly AppStateKey<bool> TodayLimit = new("today_limit", false);
    public static readonly AppStateKey<bool> TrayTitle = new("menu_bar_title", true);
}
