using System;
using System.IO;

internal static class Program
{
    private static int Main(string[] args)
    {
        Console.Title = "BAR Controller Companion Restore v0.7.0";
        string installRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "BARControllerCompanion");
        bool restoreCamera = false;
        bool noPause = false;

        for (int index = 0; index < args.Length; index++)
        {
            if (args[index] == "--restore-camera")
            {
                restoreCamera = true;
            }
            else if (args[index] == "--no-pause")
            {
                noPause = true;
            }
            else if (args[index] == "--install-root" && index + 1 < args.Length)
            {
                installRoot = args[++index];
            }
            else
            {
                Console.Error.WriteLine(
                    "Usage: BAR_Controller_Companion_Restore_v0.7.0.exe "
                    + "[--restore-camera] [--install-root path] [--no-pause]");
                return 2;
            }
        }

        try
        {
            ReleaseOperations.Restore(
                ReleaseOperations.ExpandPath(installRoot),
                restoreCamera);
            PauseIfNeeded(noPause);
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine("Restore failed: " + exception.Message);
            PauseIfNeeded(noPause);
            return 1;
        }
    }

    private static void PauseIfNeeded(bool noPause)
    {
        if (!noPause)
        {
            Console.WriteLine();
            Console.Write("Press Enter to close.");
            Console.ReadLine();
        }
    }
}
