using Microsoft.Win32;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace Telegram.Desktop;

public partial class SettingsWindow : Window
{
    public AppSettings Settings { get; private set; }

    public SettingsWindow(AppSettings current)
    {
        InitializeComponent();
        Settings = new AppSettings
        {
            Theme = current.Theme,
            ZoomFactor = current.ZoomFactor,
            IconMode = current.IconMode,
            CustomIconPath = current.CustomIconPath,
            ToolbarOrder = current.ToolbarOrder,
            HiddenToolbarItems = current.HiddenToolbarItems
        };
        ThemeBox.SelectedIndex = Settings.Theme switch { "Light" => 1, "Dark" => 2, _ => 0 };
        ZoomSlider.Value = Settings.ZoomFactor;
        IconModeBox.SelectedIndex = Settings.IconMode == "Custom" ? 1 : 0;
        CustomIconPathBox.Text = Settings.IconMode == "Custom" ? Settings.CustomIconPath ?? "" : "";
        foreach (var item in Settings.ToolbarOrder.Split(',', StringSplitOptions.RemoveEmptyEntries))
            ToolbarList.Items.Add(new ListBoxItem { Content = GetToolbarLabel(item), Tag = item });
        foreach (var item in new[] { "reload", "browser", "update", "settings", "site", "telegram" })
            if (!Settings.ToolbarOrder.Split(',').Contains(item))
                ToolbarList.Items.Add(new ListBoxItem { Content = GetToolbarLabel(item), Tag = item });
        var hidden = Settings.HiddenToolbarItems.Split(',', StringSplitOptions.RemoveEmptyEntries);
        ReloadVisible.IsChecked = !hidden.Contains("reload");
        BrowserVisible.IsChecked = !hidden.Contains("browser");
        UpdateVisible.IsChecked = !hidden.Contains("update");
        SiteVisible.IsChecked = !hidden.Contains("site");
        TelegramVisible.IsChecked = !hidden.Contains("telegram");
        UpdateZoomLabel();
    }

    private static string GetToolbarLabel(string key) => key switch
    {
        "reload" => "Обновить страницу",
        "browser" => "Открыть в браузере",
        "update" => "Проверить обновления",
        "settings" => "Настройки",
        "site" => "Мой сайт",
        "telegram" => "Telegram",
        _ => key
    };

    private void MoveUp_Click(object sender, RoutedEventArgs e) => MoveSelected(-1);
    private void MoveDown_Click(object sender, RoutedEventArgs e) => MoveSelected(1);
    private void MoveSelected(int offset)
    {
        var index = ToolbarList.SelectedIndex;
        var next = index + offset;
        if (index < 0 || next < 0 || next >= ToolbarList.Items.Count) return;
        var item = ToolbarList.Items[index];
        ToolbarList.Items.RemoveAt(index);
        ToolbarList.Items.Insert(next, item);
        ToolbarList.SelectedIndex = next;
    }

    private void BrowseIcon_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Выбери собственную иконку",
            Filter = "Иконки Windows (*.ico)|*.ico",
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) == true)
        {
            CustomIconPathBox.Text = dialog.FileName;
            IconModeBox.SelectedIndex = 1;
        }
    }

    private void ZoomSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e) => UpdateZoomLabel();
    private void UpdateZoomLabel()
    {
        if (ZoomLabel is not null) ZoomLabel.Text = $"{Math.Round(ZoomSlider.Value * 100)}%";
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        Settings.Theme = (ThemeBox.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "System";
        Settings.ZoomFactor = ZoomSlider.Value;
        Settings.IconMode = IconModeBox.SelectedIndex == 1 ? "Custom" : "Default";
        Settings.CustomIconPath = Settings.IconMode == "Custom" && !string.IsNullOrWhiteSpace(CustomIconPathBox.Text) ? CustomIconPathBox.Text.Trim() : null;
        if (Settings.IconMode == "Custom" && (string.IsNullOrWhiteSpace(Settings.CustomIconPath) || !File.Exists(Settings.CustomIconPath)))
        {
            MessageBox.Show(this, "Сначала выбери существующий файл .ico.", "Telegram Desktop", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        Settings.ToolbarOrder = string.Join(",", ToolbarList.Items.Cast<ListBoxItem>().Select(x => x.Tag?.ToString()).Where(x => !string.IsNullOrWhiteSpace(x)));
        var hidden = new List<string>();
        if (ReloadVisible.IsChecked != true) hidden.Add("reload");
        if (BrowserVisible.IsChecked != true) hidden.Add("browser");
        if (UpdateVisible.IsChecked != true) hidden.Add("update");
        if (SiteVisible.IsChecked != true) hidden.Add("site");
        if (TelegramVisible.IsChecked != true) hidden.Add("telegram");
        Settings.HiddenToolbarItems = string.Join(",", hidden);
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}