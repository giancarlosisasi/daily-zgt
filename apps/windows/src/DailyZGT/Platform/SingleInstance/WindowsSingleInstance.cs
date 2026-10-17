using System.IO;
using System.Diagnostics;
using System.IO.Pipes;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace DailyZGT.Platform;

public sealed class WindowsSingleInstance : ISingleInstance
{
    private static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(3);
    private static readonly TimeSpan ReadTimeout = TimeSpan.FromSeconds(2);

    private readonly Mutex? mutex;
    private readonly string pipeName;
    private readonly CancellationTokenSource stop = new();
    private SynchronizationContext? context;
    private Task? listener;

    public WindowsSingleInstance(string? scope = null)
    {
        scope ??= ScopeFromEnvironment();
        var suffix = scope.Length == 0 ? string.Empty : "." + scope;
        mutex = new Mutex(initiallyOwned: false, $@"Local\DailyZGT.Instance{suffix}", out var createdNew);
        IsPrimary = createdNew;
        pipeName = $"DailyZGT.Pipe.{Process.GetCurrentProcess().SessionId}.{Environment.UserName}{suffix}";
    }

    public bool IsPrimary { get; }

    public event EventHandler<IReadOnlyList<string>>? ArgumentsReceived;

    public void StartListening()
    {
        if (!IsPrimary || listener is not null)
        {
            return;
        }

        context = SynchronizationContext.Current;
        listener = Task.Run(() => ListenAsync(stop.Token));
    }

    public bool ForwardToPrimary(IReadOnlyList<string> arguments)
    {
        try
        {
            using var client = new NamedPipeClientStream(".", pipeName, PipeDirection.Out, PipeOptions.CurrentUserOnly);
            client.Connect((int)ConnectTimeout.TotalMilliseconds);
            JsonSerializer.Serialize(client, arguments);
            client.Flush();
            return true;
        }
        catch (Exception error) when (error is TimeoutException or IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    public void Dispose()
    {
        stop.Cancel();
        try
        {
            listener?.Wait(TimeSpan.FromSeconds(1));
        }
        catch (AggregateException)
        {
        }

        mutex?.Dispose();
        stop.Dispose();
    }

    private static string ScopeFromEnvironment()
    {
        var dataDir = Environment.GetEnvironmentVariable("DAILYZGT_DATA_DIR");
        if (string.IsNullOrEmpty(dataDir))
        {
            return string.Empty;
        }

        var normalized = Path.GetFullPath(dataDir).TrimEnd('\\').ToLowerInvariant();
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalized)))[..12];
    }

    private async Task ListenAsync(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                await using var server = new NamedPipeServerStream(
                    pipeName,
                    PipeDirection.In,
                    1,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
                await server.WaitForConnectionAsync(token);
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
                timeout.CancelAfter(ReadTimeout);
                var arguments = await JsonSerializer.DeserializeAsync<string[]>(server, cancellationToken: timeout.Token);
                if (arguments is not null)
                {
                    Raise(arguments);
                }
            }
            catch (OperationCanceledException)
            {
            }
            catch (Exception error) when (error is IOException or JsonException)
            {
            }
        }
    }

    private void Raise(IReadOnlyList<string> arguments)
    {
        if (context is { } ui)
        {
            ui.Post(_ => ArgumentsReceived?.Invoke(this, arguments), null);
        }
        else
        {
            ArgumentsReceived?.Invoke(this, arguments);
        }
    }
}
