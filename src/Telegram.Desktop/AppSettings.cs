using System.IO;
using System.Text.Json;

namespace Telegram.Desktop;

public sealed class AppSettings
{
    public string Theme { get; set; } = "System";
    public double ZoomFactor { get; set; } = 1.0;
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
                return new AppSettings();

            var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath))
                ?? new AppSettings();

            settings.ToolbarOrder ??= "reload,browser,update,settings,site,telegram";
            settings.HiddenToolbarItems ??= "";

            settings.ZoomFactor = double.IsFinite(settings.ZoomFactor)
                ? Math.Clamp(settings.ZoomFactor, 0.8, 1.5)
                : 1.0;

            if (settings.Theme is not ("System" or "Light" or "Dark"))
                settings.Theme = "System";

            var allowed = new[] { "reload", "browser", "update", "settings", "site", "telegram" };
            var order = settings.ToolbarOrder
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(allowed.Contains)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            foreach (var key in allowed)
                if (!order.Contains(key, StringComparer.OrdinalIgnoreCase))
                    order.Add(key);

            settings.ToolbarOrder = string.Join(",", order);
            settings.HiddenToolbarItems = string.Join(",",
                settings.HiddenToolbarItems
                    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Where(allowed.Contains)
                    .Distinct(StringComparer.OrdinalIgnoreCase));

            return settings;
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
        var temporaryPath = SettingsPath + ".tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(this,
            new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temporaryPath, SettingsPath, true);
    }
}
