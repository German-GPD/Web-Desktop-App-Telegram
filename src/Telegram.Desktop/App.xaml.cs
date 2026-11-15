using System.Threading;
using System.Windows;

namespace Telegram.Desktop;

public partial class App : Application
{
    private const string MutexName = @"Local\GermanGPD.TelegramDesktop.SingleInstance";
    private const string ActivationEventName = @"Local\GermanGPD.TelegramDesktop.SingleInstance.Activate";
    private Mutex? _instanceMutex;
    private EventWaitHandle? _activationEvent;
    private RegisteredWaitHandle? _activationRegistration;

    protected override void OnStartup(StartupEventArgs e)
    {
        _activationEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ActivationEventName);
        _instanceMutex = new Mutex(true, MutexName, out var isFirstInstance);

        if (!isFirstInstance)
        {
            try { _activationEvent.Set(); } catch (ObjectDisposedException) { }
            Shutdown();
            return;
        }

        base.OnStartup(e);
        var window = new MainWindow();
        MainWindow = window;
        window.Show();

        // Register after the main window exists so an early activation signal cannot be lost.
        _activationRegistration = ThreadPool.RegisterWaitForSingleObject(
            _activationEvent,
            (_, _) => Dispatcher.BeginInvoke(new Action(ActivateMainWindow)),
            null,
            Timeout.Infinite,
            false);
    }

    private void ActivateMainWindow()
    {
        var window = MainWindow;
        if (window is null) return;
        if (!window.IsVisible) window.Show();
        if (window.WindowState == WindowState.Minimized) window.WindowState = WindowState.Normal;
        window.Activate();
        window.Topmost = true;
        window.Topmost = false;
        window.Focus();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _activationRegistration?.Unregister(null);
        _activationEvent?.Dispose();
        if (_instanceMutex is not null)
        {
            try { _instanceMutex.ReleaseMutex(); } catch (ApplicationException) { }
            _instanceMutex.Dispose();
        }
        base.OnExit(e);
    }
}
