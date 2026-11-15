using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Win32;
using Microsoft.Web.WebView2.Core;
using System.Net.Http;
using System.Text.Json;

namespace Telegram.Desktop;

public partial class MainWindow : Window
{
    private const string StartUrl = "https://web.telegram.org/a/";
    private const int WmSettingChange = 0x001A;
    private const int WmGetMinMaxInfo = 0x0024;
    private const uint MonitorDefaultToNearest = 0x00000002;
    private const int DwmwaUseImmersiveDarkMode = 20;
    private const int DwmwaSystemBackdropType = 38;
    private const int DwmSystemBackdropMainWindow = 2;
    private const int DwmSystemBackdropTransientWindow = 3;

    private readonly string _userDataFolder = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GermanGPD", "Telegram", "WebView2");

    private HwndSource? _windowSource;
    private bool _initializationStarted;
    private AppSettings _settings = AppSettings.Load();

    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect { public int Left; public int Top; public int Right; public int Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MinMaxInfo
    {
        public NativePoint Reserved;
        public NativePoint MaxSize;
        public NativePoint MaxPosition;
        public NativePoint MinTrackSize;
        public NativePoint MaxTrackSize;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MonitorInfo
    {
        public int Size;
        public NativeRect Monitor;
        public NativeRect Work;
        public uint Flags;
    }

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    [DllImport("dwmapi.dll", PreserveSig = true)]
    private static extern int DwmSetWindowAttribute(
        IntPtr hwnd, int attribute, ref int value, int valueSize);

    public MainWindow()
    {
        InitializeComponent();
        ApplyTelegramIcon();
        ApplyToolbarSettings();
        Loaded += MainWindow_Loaded;
        PreviewKeyDown += MainWindow_PreviewKeyDown;
        Closed += MainWindow_Closed;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern void SHChangeNotify(uint eventId, uint flags, string? item1, IntPtr item2);

    private void ApplyTelegramIcon()
    {
        var iconPath = Path.Combine(AppContext.BaseDirectory, "Telegram.ico");
        if (!File.Exists(iconPath))
            return;

        try
        {
            using var iconStream = File.OpenRead(iconPath);
            var frame = BitmapFrame.Create(iconStream, BitmapCreateOptions.None, BitmapCacheOption.OnLoad);
            frame.Freeze();
            Icon = frame;
            UpdateWindowsShortcutIcons(iconPath);
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Could not load the Telegram app icon: {ex.Message}";
        }
    }

    private static void UpdateWindowsShortcutIcons(string iconPath)
    {
        var shortcuts = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Telegram.lnk"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Telegram.lnk")
        };

        var shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType is null)
            return;

        object? shell = null;
        try
        {
            shell = Activator.CreateInstance(shellType);
            if (shell is null)
                return;

            foreach (var shortcutPath in shortcuts)
            {
                if (!File.Exists(shortcutPath))
                    continue;

                object? shortcut = null;
                try
                {
                    dynamic shellObject = shell;
                    shortcut = shellObject.CreateShortcut(shortcutPath);
                    dynamic link = shortcut;
                    link.IconLocation = $"{iconPath},0";
                    link.Save();
                    SHChangeNotify(0x00002000, 0x0005, shortcutPath, IntPtr.Zero);
                }
                catch
                {
                    // Updating a locked or unavailable shortcut must not prevent startup.
                }
                finally
                {
                    if (shortcut is not null && Marshal.IsComObject(shortcut))
                        Marshal.FinalReleaseComObject(shortcut);
                }
            }
        }
        catch
        {
            // The app window keeps its icon even if shortcut updates are unavailable.
        }
        finally
        {
            if (shell is not null && Marshal.IsComObject(shell))
                Marshal.FinalReleaseComObject(shell);
        }
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        var handle = new WindowInteropHelper(this).Handle;
        _windowSource = HwndSource.FromHwnd(handle);
        _windowSource?.AddHook(WindowMessageHook);
        ApplySystemTheme();
        ApplyNativeBackdrop(handle);
    }

    private void Minimize_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void Maximize_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
        UpdateMaximizeButton();
    }

    private void Close_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }

    private void UpdateMaximizeButton()
    {
        if (MaximizeGlyph is null || MaximizeButton is null)
            return;

        var maximized = WindowState == WindowState.Maximized;
        MaximizeGlyph.Text = maximized ? "\uE923" : "\uE922";
        MaximizeButton.ToolTip = maximized ? "Restore" : "Maximize";
    }

    protected override void OnStateChanged(EventArgs e)
    {
        base.OnStateChanged(e);
        UpdateMaximizeButton();
    }

    private void MainWindow_Closed(object? sender, EventArgs e)
    {
        _windowSource?.RemoveHook(WindowMessageHook);
        _windowSource = null;
    }

    private IntPtr WindowMessageHook(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == WmGetMinMaxInfo)
        {
            ApplyMaximizedWorkArea(hwnd, lParam);
            handled = true;
            return IntPtr.Zero;
        }

        if (message == WmSettingChange)
        {
            Dispatcher.BeginInvoke(new Action(ApplySystemTheme));
            ApplyNativeBackdrop(hwnd);
        }

        return IntPtr.Zero;
    }

    private static void ApplyMaximizedWorkArea(IntPtr hwnd, IntPtr lParam)
    {
        var monitor = MonitorFromWindow(hwnd, MonitorDefaultToNearest);
        if (monitor == IntPtr.Zero)
            return;

        var monitorInfo = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
        if (!GetMonitorInfo(monitor, ref monitorInfo))
            return;

        var info = Marshal.PtrToStructure<MinMaxInfo>(lParam);
        var work = monitorInfo.Work;
        var bounds = monitorInfo.Monitor;

        info.MaxPosition = new NativePoint
        {
            X = work.Left - bounds.Left,
            Y = work.Top - bounds.Top
        };
        info.MaxSize = new NativePoint
        {
            X = work.Right - work.Left,
            Y = work.Bottom - work.Top
        };

        Marshal.StructureToPtr(info, lParam, true);
    }

    private void ApplyNativeBackdrop(IntPtr handle)
    {
        try
        {
            var dark = IsSystemDarkMode() ? 1 : 0;
            _ = DwmSetWindowAttribute(handle, DwmwaUseImmersiveDarkMode, ref dark, sizeof(int));

            var backdrop = DwmSystemBackdropMainWindow;
            var result = DwmSetWindowAttribute(handle, DwmwaSystemBackdropType, ref backdrop, sizeof(int));
            if (result != 0)
            {
                backdrop = DwmSystemBackdropTransientWindow;
                _ = DwmSetWindowAttribute(handle, DwmwaSystemBackdropType, ref backdrop, sizeof(int));
            }
        }
        catch (DllNotFoundException)
        {
            // Windows 10 fallback: keep the translucent WPF chrome without a system backdrop.
        }
        catch (EntryPointNotFoundException)
        {
            // Older Windows builds do not expose the backdrop API.
        }
    }

    private static bool IsSystemDarkMode()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return Convert.ToInt32(key?.GetValue("AppsUseLightTheme", 1)) == 0;
        }
        catch
        {
            return false;
        }
    }

    private void ApplySystemTheme()
    {
        var dark = _settings.Theme switch { "Dark" => true, "Light" => false, _ => IsSystemDarkMode() };

        SetBrush("ChromeBackground", dark
            ? Color.FromRgb(35, 37, 35)
            : Color.FromRgb(241, 242, 240));
        SetBrush("ChromeBorder", dark
            ? Color.FromRgb(65, 69, 65)
            : Color.FromRgb(215, 218, 214));
        SetBrush("TextPrimary", dark
            ? Color.FromRgb(239, 245, 240)
            : Color.FromRgb(31, 42, 35));
        SetBrush("TextSecondary", dark
            ? Color.FromRgb(166, 181, 170)
            : Color.FromRgb(101, 114, 104));
        SetBrush("ButtonHover", dark
            ? Color.FromRgb(58, 62, 58)
            : Color.FromRgb(226, 229, 225));
        SetBrush("ErrorBackground", dark
            ? Color.FromArgb(246, 25, 32, 28)
            : Color.FromArgb(246, 248, 250, 248));

        if (Browser.CoreWebView2 is not null)
            Browser.CoreWebView2.Profile.PreferredColorScheme = GetPreferredColorScheme();
    }

    private void SetBrush(string key, Color color)
    {
        var brush = new SolidColorBrush(color);
        brush.Freeze();
        Resources[key] = brush;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        await InitializeBrowserAsync();
        _ = CheckForUpdatesAsync(showUpToDate: false);
    }

    private async Task InitializeBrowserAsync()
    {
        if (_initializationStarted)
            return;

        _initializationStarted = true;

        try
        {
            Directory.CreateDirectory(_userDataFolder);
            var environment = await CoreWebView2Environment.CreateAsync(
                browserExecutableFolder: null,
                userDataFolder: _userDataFolder);

            await Browser.EnsureCoreWebView2Async(environment);
            ConfigureBrowser(Browser.CoreWebView2);
            Browser.Source = new Uri(StartUrl);
        }
        catch (Exception ex)
        {
            _initializationStarted = false;
            ShowError($"WebView2 could not start. Check that Microsoft Edge WebView2 Runtime is installed, then try again.\n\n{ex.Message}");
        }
    }

    private void ConfigureBrowser(CoreWebView2 core)
    {
        core.Settings.IsStatusBarEnabled = false;
        core.Settings.AreDefaultContextMenusEnabled = true;
        core.Settings.IsZoomControlEnabled = true;
        core.Settings.AreDevToolsEnabled = false;
        core.Profile.PreferredColorScheme = GetPreferredColorScheme();
        Browser.ZoomFactor = _settings.ZoomFactor;

        core.PermissionRequested += (_, e) =>
        {
            var permissionName = e.PermissionKind switch
            {
                CoreWebView2PermissionKind.Camera => "camera",
                CoreWebView2PermissionKind.Microphone => "microphone",
                _ => null
            };

            if (permissionName is null)
            {
                e.State = CoreWebView2PermissionState.Deny;
                return;
            }

            var answer = MessageBox.Show(
                this,
                $"Allow web.telegram.org/a/ to access your {permissionName}?",
                "Telegram website permission",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question,
                MessageBoxResult.No);

            e.State = answer == MessageBoxResult.Yes
                ? CoreWebView2PermissionState.Allow
                : CoreWebView2PermissionState.Deny;
            e.SavesInProfile = answer == MessageBoxResult.Yes;
        };

        core.DownloadStarting += Browser_DownloadStarting;

        core.DocumentTitleChanged += (_, _) =>
        {
            var title = core.DocumentTitle;
            Title = string.IsNullOrWhiteSpace(title) ? "Telegram Desktop" : $"{title} — Telegram Desktop";
        };

        core.NavigationStarting += (_, _) =>
        {
            StatusText.Text = "Connecting to the official Telegram website…";
            StatusDot.Fill = new SolidColorBrush(Color.FromRgb(214, 157, 56));
        };

        core.NavigationCompleted += (_, args) =>
        {
            if (args.IsSuccess)
            {
                HideError();
                StatusText.Text = "Connected to the official Telegram website";
                StatusDot.Fill = new SolidColorBrush(Color.FromRgb(16, 163, 127));
            }
            else
            {
                StatusText.Text = $"Unable to load Telegram ({args.WebErrorStatus})";
                StatusDot.Fill = new SolidColorBrush(Color.FromRgb(205, 75, 75));
                ShowError($"The website could not be loaded. Check your internet connection and try again.\n\nError: {args.WebErrorStatus}");
            }
        };
    }

    private void Browser_DownloadStarting(object? sender, CoreWebView2DownloadStartingEventArgs e)
    {
        var operation = e.DownloadOperation;
        var suggestedName = Path.GetFileName(operation.ResultFilePath);
        if (string.IsNullOrWhiteSpace(suggestedName))
            suggestedName = "Telegram-download";

        var dialog = new SaveFileDialog
        {
            Title = "Save download",
            FileName = suggestedName,
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            AddExtension = true,
            OverwritePrompt = true
        };

        if (dialog.ShowDialog(this) != true)
        {
            e.Cancel = true;
            e.Handled = true;
            StatusText.Text = "Download cancelled";
            return;
        }

        e.ResultFilePath = dialog.FileName;
        e.Handled = true;
        StatusText.Text = $"Downloading {Path.GetFileName(dialog.FileName)}…";

        operation.StateChanged += (_, _) => Dispatcher.BeginInvoke(new Action(() =>
        {
            if (operation.State == CoreWebView2DownloadState.Completed)
                StatusText.Text = $"Downloaded {Path.GetFileName(dialog.FileName)}";
            else if (operation.State == CoreWebView2DownloadState.Interrupted)
                StatusText.Text = $"Download interrupted: {operation.InterruptReason}";
        }));
    }

    private void MainWindow_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (Browser.CoreWebView2 is null)
            return;

        if ((Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.R) || e.Key == Key.F5)
        {
            Browser.CoreWebView2.Reload();
            e.Handled = true;
        }
        else if (Keyboard.Modifiers == ModifierKeys.Alt && e.Key == Key.Left)
        {
            if (Browser.CoreWebView2.CanGoBack)
                Browser.CoreWebView2.GoBack();
            e.Handled = true;
        }
        else if (Keyboard.Modifiers == ModifierKeys.Alt && e.Key == Key.Right)
        {
            if (Browser.CoreWebView2.CanGoForward)
                Browser.CoreWebView2.GoForward();
            e.Handled = true;
        }
    }

    private void Reload_Click(object sender, RoutedEventArgs e)
    {
        if (Browser.CoreWebView2 is not null)
            Browser.CoreWebView2.Reload();
        else
            _ = InitializeBrowserAsync();
    }

    private CoreWebView2PreferredColorScheme GetPreferredColorScheme() => _settings.Theme switch
    {
        "Dark" => CoreWebView2PreferredColorScheme.Dark,
        "Light" => CoreWebView2PreferredColorScheme.Light,
        _ => CoreWebView2PreferredColorScheme.Auto
    };


    private void ApplyToolbarSettings()
    {
        if (ToolbarPanel is null) return;
        var controls = new Dictionary<string, FrameworkElement>
        {
            ["reload"] = ReloadButton, ["browser"] = BrowserButton, ["update"] = UpdateButton,
            ["settings"] = SettingsButton, ["site"] = SiteButton, ["telegram"] = TelegramButton
        };
        var hidden = _settings.HiddenToolbarItems.Split(',', StringSplitOptions.RemoveEmptyEntries).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in controls) pair.Value.Visibility = hidden.Contains(pair.Key) ? Visibility.Collapsed : Visibility.Visible;
        var ordered = _settings.ToolbarOrder.Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Where(controls.ContainsKey).Distinct().ToList();
        foreach (var key in controls.Keys) if (!ordered.Contains(key)) ordered.Add(key);
        ToolbarPanel.Children.Clear();
        foreach (var key in ordered) ToolbarPanel.Children.Add(controls[key]);
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SettingsWindow(_settings) { Owner = this };
        if (dialog.ShowDialog() != true) return;

        _settings = dialog.Settings;
        ApplyToolbarSettings();
        try { _settings.Save(); }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Settings could not be saved.\\n\\n{ex.Message}", "Telegram Desktop", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        ApplySystemTheme();
        if (Browser.CoreWebView2 is not null)
        {
            Browser.CoreWebView2.Profile.PreferredColorScheme = GetPreferredColorScheme();
            Browser.ZoomFactor = _settings.ZoomFactor;
        }
    }

    private void OpenSite_Click(object sender, RoutedEventArgs e)
    {
        OpenExternalUrl("https://german-gpd.github.io/about-german/");
    }

    private void OpenTelegram_Click(object sender, RoutedEventArgs e)
    {
        OpenExternalUrl("https://t.me/german_gpd");
    }

    private void OpenExternalUrl(string url)
    {
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Could not open link: {ex.Message}";
        }
    }

    private void OpenBrowser_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo(StartUrl) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Could not open browser: {ex.Message}";
        }
    }

    private async void Retry_Click(object sender, RoutedEventArgs e)
    {
        HideError();
        if (Browser.CoreWebView2 is not null)
            Browser.CoreWebView2.Reload();
        else
            await InitializeBrowserAsync();
    }

    private void ShowError(string message)
    {
        ErrorMessage.Text = message;
        ErrorPanel.Visibility = Visibility.Visible;
        StatusText.Text = "Connection error";
        StatusDot.Fill = new SolidColorBrush(Color.FromRgb(205, 75, 75));
    }

    private void HideError() => ErrorPanel.Visibility = Visibility.Collapsed;

    private static readonly HttpClient UpdateHttp = CreateUpdateHttpClient();
    private const string LatestReleaseApi = "https://api.github.com/repos/German-GPD/Web-Desktop-App-Telegram/releases/latest";
    private const string InstallerAssetName = "Telegram-Setup.exe";
    private const string ExecutableName = "Telegram.exe";
    private bool _updateCheckRunning;

    private static HttpClient CreateUpdateHttpClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromMinutes(5) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("German-GPD-Desktop-Updater");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }

    private async void CheckForUpdates_Click(object sender, RoutedEventArgs e)
    {
        await CheckForUpdatesAsync(showUpToDate: true);
    }

    private async Task CheckForUpdatesAsync(bool showUpToDate)
    {
        if (_updateCheckRunning) return;
        _updateCheckRunning = true;
        try
        {
            StatusText.Text = "Checking for updates…";
            using var response = await UpdateHttp.GetAsync(LatestReleaseApi, HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();
            await using var stream = await response.Content.ReadAsStreamAsync();
            using var json = await JsonDocument.ParseAsync(stream);
            var root = json.RootElement;

            if (root.TryGetProperty("draft", out var draft) && draft.GetBoolean() ||
                root.TryGetProperty("prerelease", out var prerelease) && prerelease.GetBoolean())
                throw new InvalidOperationException("The latest GitHub release is not a stable release.");

            var tag = root.GetProperty("tag_name").GetString()?.TrimStart('v');
            if (!Version.TryParse(tag, out var latestVersion))
                throw new InvalidOperationException("The release version is invalid.");

            var currentVersion = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version ?? new Version(1, 0, 0);
            if (latestVersion <= currentVersion)
            {
                StatusText.Text = "You're up to date";
                if (showUpToDate)
                    MessageBox.Show(this, $"You're using the latest version ({currentVersion}).", "Telegram Desktop", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var asset = root.GetProperty("assets").EnumerateArray()
                .FirstOrDefault(item => string.Equals(item.GetProperty("name").GetString(), InstallerAssetName, StringComparison.OrdinalIgnoreCase));
            if (asset.ValueKind == JsonValueKind.Undefined)
                throw new InvalidOperationException("The update installer is not attached to the latest release.");

            var downloadUrl = asset.GetProperty("browser_download_url").GetString();
            if (string.IsNullOrWhiteSpace(downloadUrl) || !downloadUrl.StartsWith("https://github.com/", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("The update download link is not trusted.");

            var answer = MessageBox.Show(this,
                $"A new version is available: {latestVersion}.\nYou're using {currentVersion}.\n\nDownload and install it now?",
                "Telegram Desktop update", MessageBoxButton.YesNo, MessageBoxImage.Information, MessageBoxResult.Yes);
            if (answer != MessageBoxResult.Yes)
            {
                StatusText.Text = $"Update {latestVersion} available";
                return;
            }

            StatusText.Text = "Downloading update…";
            var installerPath = Path.Combine(Path.GetTempPath(), $"Telegram-Desktop-Update-{latestVersion}.exe");
            using (var download = await UpdateHttp.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead))
            {
                download.EnsureSuccessStatusCode();
                await using var input = await download.Content.ReadAsStreamAsync();
                await using var output = new FileStream(installerPath, FileMode.Create, FileAccess.Write, FileShare.None);
                await input.CopyToAsync(output);
            }

            if (!File.Exists(installerPath) || new FileInfo(installerPath).Length < 1_000_000)
                throw new InvalidOperationException("The downloaded installer is incomplete.");

            var checksumAsset = root.GetProperty("assets").EnumerateArray()
                .FirstOrDefault(item => string.Equals(item.GetProperty("name").GetString(), InstallerAssetName + ".sha256", StringComparison.OrdinalIgnoreCase));
            if (checksumAsset.ValueKind == JsonValueKind.Undefined)
                throw new InvalidOperationException("The release does not include a SHA-256 checksum. The update was not installed.");

            var checksumUrl = checksumAsset.GetProperty("browser_download_url").GetString();
            if (string.IsNullOrWhiteSpace(checksumUrl) || !checksumUrl.StartsWith("https://github.com/", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("The checksum download link is not trusted.");

            var checksumText = await UpdateHttp.GetStringAsync(checksumUrl);
            var expectedHash = checksumText.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            if (expectedHash is null || expectedHash.Length != 64 || !expectedHash.All(Uri.IsHexDigit))
                throw new InvalidOperationException("The release SHA-256 checksum is invalid.");

            await using (var hashStream = File.OpenRead(installerPath))
            {
                var actualHash = Convert.ToHexString(await System.Security.Cryptography.SHA256.HashDataAsync(hashStream));
                if (!string.Equals(actualHash, expectedHash, StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(installerPath);
                    throw new InvalidOperationException("The installer failed SHA-256 verification and was deleted.");
                }
            }

            var appPath = Path.Combine(AppContext.BaseDirectory, ExecutableName);
            var scriptPath = Path.Combine(Path.GetTempPath(), $"Telegram-Desktop-Update-{Guid.NewGuid():N}.cmd");
            var script = "@echo off\r\n" +
                "start \"\" /wait \"" + installerPath + "\" /SILENT /CLOSEAPPLICATIONS /NORESTART\r\n" +
                "if exist \"" + appPath + "\" start \"\" \"" + appPath + "\"\r\n" +
                "del \"%~f0\"\r\n";
            await File.WriteAllTextAsync(scriptPath, script, new System.Text.UTF8Encoding(false));

            Process.Start(new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c \"\"{scriptPath}\"\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            });
            Application.Current.Shutdown();
        }
        catch (Exception ex)
        {
            StatusText.Text = "Update check failed";
            MessageBox.Show(this, $"Couldn't check or install updates.\n\n{ex.Message}", "Telegram Desktop", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally
        {
            _updateCheckRunning = false;
        }
    }

}