using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

internal enum ConsolePromptState
{
    None,
    UpdateChoice,
    ReleaseNotes,
    RecoveryBrowser,
    Confirmation,
    Installing,
    Restarting,
    ShuttingDown
}

internal interface IConsoleInput
{
    string? ReadLine();
    bool IsRedirected { get; }
}

internal interface IConsoleOutput
{
    void Write(string value);
    void WriteLine(string value);
    void WriteLine(string value, ConsoleColor color);
    bool IsRedirected { get; }
}

internal sealed class StandardConsoleInput : IConsoleInput
{
    public string? ReadLine() => Console.ReadLine();
    public bool IsRedirected => Console.IsInputRedirected;
}

internal sealed class StandardConsoleOutput : IConsoleOutput
{
    public bool IsRedirected => Console.IsOutputRedirected;

    public void Write(string value) => Console.Write(value);

    public void WriteLine(string value)
    {
        Console.WriteLine(value);
    }

    public void WriteLine(string value, ConsoleColor color)
    {
        bool useColor = BridgeConsole.SupportsColor(Console.IsOutputRedirected, Environment.GetEnvironmentVariable("NO_COLOR"));
        if (!useColor)
        {
            Console.WriteLine(value);
            return;
        }

        ConsoleColor prev = Console.ForegroundColor;
        try
        {
            Console.ForegroundColor = color;
            Console.WriteLine(value);
        }
        catch
        {
            Console.WriteLine(value);
        }
        finally
        {
            try { Console.ForegroundColor = prev; } catch { }
        }
    }
}

internal sealed class TestConsoleInput : IConsoleInput
{
    private readonly TextReader _reader;
    public TestConsoleInput(TextReader reader, bool isRedirected = false)
    {
        _reader = reader;
        IsRedirected = isRedirected;
    }
    public string? ReadLine() => _reader.ReadLine();
    public bool IsRedirected { get; }
}

internal sealed class TestConsoleOutput : IConsoleOutput
{
    private readonly TextWriter _writer;
    public TestConsoleOutput(TextWriter writer, bool isRedirected = false)
    {
        _writer = writer;
        IsRedirected = isRedirected;
    }
    public bool IsRedirected { get; }
    public void Write(string value) => _writer.Write(value);
    public void WriteLine(string value) => _writer.WriteLine(value);
    public void WriteLine(string value, ConsoleColor color) => _writer.WriteLine(value);
}

internal interface IConsoleSession
{
    IConsoleInput Input { get; }
    IConsoleOutput Output { get; }
    ConsolePromptState State { get; }
    void SetState(ConsolePromptState newState);
    bool IsInteractive { get; }
    void PauseStatusRedraw();
    void ResumeStatusRedraw();
    void WriteStatus(string label, string value, BridgeTone tone = BridgeTone.Neutral);
    void WriteLine(string value, BridgeTone tone = BridgeTone.Neutral);
    string? ReadLine();
}

internal sealed class ConsoleInteractionCoordinator : IConsoleSession
{
    private static ConsoleInteractionCoordinator? _instance;
    private static readonly object InstanceLock = new object();

    public static ConsoleInteractionCoordinator Instance
    {
        get
        {
            lock (InstanceLock)
            {
                _instance ??= new ConsoleInteractionCoordinator(new StandardConsoleInput(), new StandardConsoleOutput());
                return _instance;
            }
        }
    }

    public static void SetInstanceForTest(ConsoleInteractionCoordinator coordinator)
    {
        lock (InstanceLock)
        {
            _instance = coordinator;
        }
    }

    public static void ResetInstance()
    {
        lock (InstanceLock)
        {
            _instance = null;
        }
    }

    private readonly object _stateLock = new object();
    private readonly object _outputLock = new object();
    private ConsolePromptState _currentState = ConsolePromptState.None;
    private bool _statusRedrawPaused = false;
    private string? _pendingStatusLabel;
    private string? _pendingStatusValue;
    private BridgeTone _pendingStatusTone;

    public IConsoleInput Input { get; }
    public IConsoleOutput Output { get; }

    public ConsoleInteractionCoordinator(IConsoleInput input, IConsoleOutput output)
    {
        Input = input;
        Output = output;
    }

    public ConsolePromptState State
    {
        get
        {
            lock (_stateLock)
            {
                return _currentState;
            }
        }
    }

    public void SetState(ConsolePromptState newState)
    {
        lock (_stateLock)
        {
            _currentState = newState;
            if (newState == ConsolePromptState.UpdateChoice
                || newState == ConsolePromptState.ReleaseNotes
                || newState == ConsolePromptState.RecoveryBrowser
                || newState == ConsolePromptState.Confirmation
                || newState == ConsolePromptState.Installing)
            {
                _statusRedrawPaused = true;
            }
            else if (newState == ConsolePromptState.None)
            {
                _statusRedrawPaused = false;
            }
        }
    }

    public bool IsInteractive => !Input.IsRedirected && !Output.IsRedirected;

    public void PauseStatusRedraw()
    {
        lock (_stateLock)
        {
            _statusRedrawPaused = true;
        }
    }

    public void ResumeStatusRedraw()
    {
        string? labelToFlush = null;
        string? valueToFlush = null;
        BridgeTone toneToFlush = BridgeTone.Neutral;

        lock (_stateLock)
        {
            _statusRedrawPaused = false;
            if (_pendingStatusLabel != null && _pendingStatusValue != null)
            {
                labelToFlush = _pendingStatusLabel;
                valueToFlush = _pendingStatusValue;
                toneToFlush = _pendingStatusTone;
                _pendingStatusLabel = null;
                _pendingStatusValue = null;
            }
        }

        if (labelToFlush != null && valueToFlush != null)
        {
            WriteStatus(labelToFlush, valueToFlush, toneToFlush);
        }
    }

    public void WriteStatus(string label, string value, BridgeTone tone = BridgeTone.Neutral)
    {
        lock (_outputLock)
        {
            lock (_stateLock)
            {
                if (_statusRedrawPaused && _currentState != ConsolePromptState.None)
                {
                    _pendingStatusLabel = label;
                    _pendingStatusValue = value;
                    _pendingStatusTone = tone;
                    return;
                }
            }

            string text = "[" + BridgeConsole.ToAscii(label) + "] " + BridgeConsole.ToAscii(value);
            Output.WriteLine(text, BridgeConsole.ToneColor(tone));
        }
    }

    public void WriteLine(string value, BridgeTone tone = BridgeTone.Neutral)
    {
        lock (_outputLock)
        {
            Output.WriteLine(BridgeConsole.ToAscii(value), BridgeConsole.ToneColor(tone));
        }
    }

    public string? ReadLine()
    {
        return Input.ReadLine();
    }
}
