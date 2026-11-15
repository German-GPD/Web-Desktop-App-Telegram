using System.IO;
using Microsoft.Win32;
using System.Text.Json;

namespace Telegram.Desktop;

public sealed class AppSettings
{
    public string Theme { get; set; } = "System";
    public double ZoomFactor { get; set; } = 1.0;
    public string IconMode { get; set; } = "Default";
    public string? CustomIconPath { get; set; }
    public string ToolbarOrder { get; set; } = "reload,browser,update,settings,site,telegram";
    public string HiddenToolbarItems { get; set; } = "";

    private static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GermanGPD", "Telegram", "settings.json");

    public static AppSettings Load()
    {
        try
        {
            if (!File.Exists(SettingsPath))
            {
                var fresh = new AppSettings();
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\GermanGPD\Telegram");
                var installedMode = key?.GetValue("InstalledIconMode")?.ToString();
                if (installedMode is "Custom" or "Default") fresh.IconMode = installedMode;
                return fresh;
            }
            var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath)) ?? new AppSettings();
            if (string.IsNullOrWhiteSpace(settings.CustomIconPath))
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\GermanGPD\Telegram");
                var installedMode = key?.GetValue("InstalledIconMode")?.ToString();
                if (installedMode is "Custom" or "Default") settings.IconMode = installedMode;
            }
            settings.ZoomFactor = Math.Clamp(settings.ZoomFactor, 0.8, 1.5);
            if (settings.Theme is not ("System" or "Light" or "Dark")) settings.Theme = "System";
            if (settings.IconMode is not ("Default" or "Custom")) settings.IconMode = "Default";
            if (string.IsNullOrWhiteSpace(settings.ToolbarOrder)) settings.ToolbarOrder = "reload,browser,update,settings,site,telegram";
            settings.HiddenToolbarItems ??= "";
            return settings;
        }
        catch { return new AppSettings(); }
    }

    public void Save()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
        File.WriteAllText(SettingsPath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}