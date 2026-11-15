(() => {
  const root = document.documentElement;
  const button = document.getElementById('themeToggle');
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  let preference = 'system';

  try {
    preference = localStorage.getItem('chatgpt-desktop-theme') || 'system';
  } catch {
    preference = 'system';
  }

  const applyTheme = () => {
    const resolved = preference === 'system' ? (media.matches ? 'dark' : 'light') : preference;
    root.dataset.theme = resolved;
    if (button) {
      const label = preference === 'system' ? 'System theme' : preference === 'dark' ? 'Dark theme' : 'Light theme';
      button.setAttribute('aria-label', `Theme: ${label}. Click to change.`);
      button.title = `Theme: ${label}`;
    }
  };

  button?.addEventListener('click', () => {
    preference = preference === 'system' ? 'light' : preference === 'light' ? 'dark' : 'system';
    try {
      if (preference === 'system') localStorage.removeItem('chatgpt-desktop-theme');
      else localStorage.setItem('chatgpt-desktop-theme', preference);
    } catch {}
    applyTheme();
  });

  media.addEventListener?.('change', () => {
    if (preference === 'system') applyTheme();
  });

  applyTheme();
})();