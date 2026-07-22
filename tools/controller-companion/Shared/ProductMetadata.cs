using System;
using System.Reflection;

internal static class ProductMetadata
{
    private static readonly string informationalVersion =
        typeof(ProductMetadata).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion ?? "0.0.0+Unknown";

    public static string SemanticVersion
    {
        get
        {
            int separator = informationalVersion.IndexOf('+');
            return separator < 0 ? informationalVersion : informationalVersion.Substring(0, separator);
        }
    }

    public static string Channel
    {
        get
        {
            int separator = informationalVersion.IndexOf('+');
            return separator < 0 || separator + 1 >= informationalVersion.Length
                ? "Unknown"
                : informationalVersion.Substring(separator + 1);
        }
    }

    public static string DisplayVersion => "v" + SemanticVersion + " " + Channel;
    public static string BridgeBanner => "BAR Controller Bridge " + DisplayVersion;
    public static string InstallerFileName =>
        "BAR_Controller_Companion_Installer_v" + SemanticVersion + "_" + Channel + ".exe";
    public static string RestoreFileName =>
        "BAR_Controller_Companion_Restore_v" + SemanticVersion + "_" + Channel + ".exe";
}
