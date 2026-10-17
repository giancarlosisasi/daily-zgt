namespace DailyZGT.Platform;

public readonly record struct ScreenRect(int Left, int Top, int Right, int Bottom)
{
    public int Width => Right - Left;

    public int Height => Bottom - Top;
}

public interface ITrayIcon : IDisposable
{
    event EventHandler? Clicked;

    event EventHandler? OpenRequested;

    event EventHandler? QuitRequested;

    void Show();

    void Update(int? count, string tooltip);

    ScreenRect? GetScreenRect();
}
