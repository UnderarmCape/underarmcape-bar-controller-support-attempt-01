using System;
using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class Program
{
    private const string ProtocolMagic = "BARCTRL1";
    private const int DefaultPort = 28777;
    private const int DefaultRateHz = 120;
    private const int ButtonCount = 21;
    private const uint ErrorSuccess = 0;
    private static volatile bool keepRunning = true;

    private static int Main(string[] args)
    {
        if (!TryParseArguments(
            args,
            out int port,
            out int rateHz,
            out string? settingsPath,
            out bool configureOnly,
            out bool verbose))
        {
            PrintUsage();
            return 2;
        }

        using var singleInstanceMutex = new Mutex(
            true,
            @"Local\BARControllerBridge-v0.5.0",
            out bool ownsMutex);
        if (!ownsMutex)
        {
            Console.WriteLine("BARControllerBridge.exe is already running.");
            return 0;
        }

        Console.CancelKeyPress += (_, eventArgs) =>
        {
            eventArgs.Cancel = true;
            keepRunning = false;
        };

        CameraSettingResult cameraSetting =
            CameraSettings.EnsureCardinalDirectionLockDisabled(settingsPath);
        Console.WriteLine("BAR Controller Bridge v0.5.0");
        Console.WriteLine("Camera setting: " + GetCameraStatus(cameraSetting.Status));
        if (verbose)
        {
            Console.WriteLine(cameraSetting.Message);
            if (cameraSetting.BackupPath != null)
            {
                Console.WriteLine("Camera settings backup: " + cameraSetting.BackupPath);
            }
        }
        if (cameraSetting.WasModified && CameraSettings.IsBarRunning())
        {
            Console.WriteLine(
                "BAR must be restarted for CamSpringLockCardinalDirections = 0 to take effect.");
        }
        if (configureOnly)
        {
            return cameraSetting.Status == CameraSettingStatus.Failed ? 1 : 0;
        }

        using var udp = new UdpClient(AddressFamily.InterNetwork);
        var destination = new IPEndPoint(IPAddress.Loopback, port);

        Console.WriteLine($"UDP: 127.0.0.1:{port}");
        Console.WriteLine("Status: waiting for controller");
        Console.WriteLine("Press Ctrl+C to stop.");

        uint sequence = 0;
        bool? lastConnected = null;
        bool hasConnected = false;
        long packetsThisSecond = 0;
        var reportTimer = Stopwatch.StartNew();
        var loopTimer = Stopwatch.StartNew();
        double intervalMilliseconds = 1000.0 / rateHz;
        double nextSendMilliseconds = 0;
        bool sendErrorReported = false;

        while (keepRunning)
        {
            bool connected = XInputGetState(0, out XInputState state) == ErrorSuccess;
            if (connected != lastConnected)
            {
                if (connected)
                {
                    Console.WriteLine(hasConnected ? "Controller reconnected" : "Controller connected");
                    hasConnected = true;
                }
                else if (lastConnected == true)
                {
                    Console.WriteLine("Controller disconnected");
                }
                lastConnected = connected;
            }

            string packet = BuildPacket(sequence++, connected, state.Gamepad);
            byte[] payload = Encoding.ASCII.GetBytes(packet);
            try
            {
                udp.Send(payload, payload.Length, destination);
                packetsThisSecond++;
                if (sendErrorReported)
                {
                    Console.WriteLine("UDP packet sending resumed.");
                    sendErrorReported = false;
                }
            }
            catch (SocketException exception)
            {
                if (!sendErrorReported)
                {
                    Console.WriteLine(
                        "UDP send is temporarily unavailable; retrying: " + exception.Message);
                    sendErrorReported = true;
                }
            }

            if (verbose && reportTimer.ElapsedMilliseconds >= 1000)
            {
                double seconds = reportTimer.Elapsed.TotalSeconds;
                Console.WriteLine(
                    $"{DateTime.Now:HH:mm:ss} packets={packetsThisSecond / seconds:F1}/s " +
                    $"controller={(connected ? "connected" : "disconnected")} sequence={sequence - 1}");
                packetsThisSecond = 0;
                reportTimer.Restart();
            }

            nextSendMilliseconds += intervalMilliseconds;
            double remaining = nextSendMilliseconds - loopTimer.Elapsed.TotalMilliseconds;
            if (remaining >= 1)
            {
                Thread.Sleep((int)remaining);
            }
            else if (remaining < -1000)
            {
                nextSendMilliseconds = loopTimer.Elapsed.TotalMilliseconds;
            }
        }

        Console.WriteLine("Stopped.");
        return 0;
    }

    private static string GetCameraStatus(CameraSettingStatus status)
    {
        return status switch
        {
            CameraSettingStatus.AlreadyOk => "OK",
            CameraSettingStatus.Added => "Added",
            CameraSettingStatus.Changed => "Changed",
            CameraSettingStatus.NotFound => "Not found",
            _ => "Failed",
        };
    }

    private static string BuildPacket(uint sequence, bool connected, XInputGamepad gamepad)
    {
        if (!connected)
        {
            gamepad = default;
        }

        int leftY = InvertYAxis(gamepad.LeftThumbY);
        int rightY = InvertYAxis(gamepad.RightThumbY);
        int leftTrigger = ScaleTrigger(gamepad.LeftTrigger);
        int rightTrigger = ScaleTrigger(gamepad.RightTrigger);
        string buttons = BuildButtons(gamepad.Buttons);

        return string.Join(
            "|",
            ProtocolMagic,
            sequence.ToString(CultureInfo.InvariantCulture),
            connected ? "1" : "0",
            gamepad.LeftThumbX.ToString(CultureInfo.InvariantCulture),
            leftY.ToString(CultureInfo.InvariantCulture),
            gamepad.RightThumbX.ToString(CultureInfo.InvariantCulture),
            rightY.ToString(CultureInfo.InvariantCulture),
            leftTrigger.ToString(CultureInfo.InvariantCulture),
            rightTrigger.ToString(CultureInfo.InvariantCulture),
            buttons);
    }

    private static int InvertYAxis(short value)
    {
        return value == short.MinValue ? short.MaxValue : -value;
    }

    private static int ScaleTrigger(byte value)
    {
        return (value * short.MaxValue + 127) / byte.MaxValue;
    }

    private static string BuildButtons(ushort buttons)
    {
        var result = new char[ButtonCount];
        Array.Fill(result, '0');

        SetButton(result, 0, buttons, XInputButtons.A);
        SetButton(result, 1, buttons, XInputButtons.B);
        SetButton(result, 2, buttons, XInputButtons.X);
        SetButton(result, 3, buttons, XInputButtons.Y);
        SetButton(result, 4, buttons, XInputButtons.Back);
        // SDL button 5 is Guide. XInputGetState does not expose it.
        SetButton(result, 6, buttons, XInputButtons.Start);
        SetButton(result, 7, buttons, XInputButtons.LeftThumb);
        SetButton(result, 8, buttons, XInputButtons.RightThumb);
        SetButton(result, 9, buttons, XInputButtons.LeftShoulder);
        SetButton(result, 10, buttons, XInputButtons.RightShoulder);
        SetButton(result, 11, buttons, XInputButtons.DPadUp);
        SetButton(result, 12, buttons, XInputButtons.DPadDown);
        SetButton(result, 13, buttons, XInputButtons.DPadLeft);
        SetButton(result, 14, buttons, XInputButtons.DPadRight);

        return new string(result);
    }

    private static void SetButton(char[] result, int index, ushort buttons, XInputButtons button)
    {
        if ((buttons & (ushort)button) != 0)
        {
            result[index] = '1';
        }
    }

    private static bool TryParseArguments(
        string[] args,
        out int port,
        out int rateHz,
        out string? settingsPath,
        out bool configureOnly,
        out bool verbose)
    {
        port = DefaultPort;
        rateHz = DefaultRateHz;
        settingsPath = null;
        configureOnly = false;
        verbose = false;

        for (int i = 0; i < args.Length; i++)
        {
            string argument = args[i];
            if (argument == "--port" && i + 1 < args.Length)
            {
                if (!int.TryParse(args[++i], out port) || port < 1024 || port > 65535)
                {
                    return false;
                }
            }
            else if (argument == "--rate" && i + 1 < args.Length)
            {
                if (!int.TryParse(args[++i], out rateHz) || rateHz < 10 || rateHz > 1000)
                {
                    return false;
                }
            }
            else if (argument == "--settings-file" && i + 1 < args.Length)
            {
                settingsPath = args[++i];
            }
            else if (argument == "--configure-only")
            {
                configureOnly = true;
            }
            else if (argument == "--verbose")
            {
                verbose = true;
            }
            else
            {
                return false;
            }
        }

        return true;
    }

    private static void PrintUsage()
    {
        Console.Error.WriteLine(
            "Usage: BARControllerBridge [--port 28777] [--rate 120] " +
            "[--settings-file path] [--configure-only] [--verbose]");
    }

    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
    private static extern uint XInputGetState(uint userIndex, out XInputState state);

    [StructLayout(LayoutKind.Sequential)]
    private struct XInputState
    {
        public uint PacketNumber;
        public XInputGamepad Gamepad;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct XInputGamepad
    {
        public ushort Buttons;
        public byte LeftTrigger;
        public byte RightTrigger;
        public short LeftThumbX;
        public short LeftThumbY;
        public short RightThumbX;
        public short RightThumbY;
    }

    [Flags]
    private enum XInputButtons : ushort
    {
        DPadUp = 0x0001,
        DPadDown = 0x0002,
        DPadLeft = 0x0004,
        DPadRight = 0x0008,
        Start = 0x0010,
        Back = 0x0020,
        LeftThumb = 0x0040,
        RightThumb = 0x0080,
        LeftShoulder = 0x0100,
        RightShoulder = 0x0200,
        A = 0x1000,
        B = 0x2000,
        X = 0x4000,
        Y = 0x8000,
    }
}
