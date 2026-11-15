(() => {
  const root = document.documentElement;
  const button = document.getElementById("themeToggle");
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  const storageKey = "telegram-desktop-theme";
  let preference = "system";

  try {
    const stored = localStorage.getItem(storageKey);
    if (stored === "light" || stored === "dark") preference = stored;
  } catch {
    preference = "system";
  }

  const applyTheme = () => {
    root.dataset.theme = preference === "system"
      ? (media.matches ? "dark" : "light")
      : preference;

    if (button) {
      const label = preference === "system"
        ? "Системная тема"
        : preference === "dark" ? "Тёмная тема" : "Светлая тема";
      button.setAttribute("aria-label", "Тема: " + label + ". Нажми, чтобы изменить.");
      button.title = "Тема: " + label;
    }
  };

  button?.addEventListener("click", () => {
    preference = preference === "system" ? "light"
      : preference === "light" ? "dark" : "system";

    try {
      if (preference === "system") localStorage.removeItem(storageKey);
      else localStorage.setItem(storageKey, preference);
    } catch {
      // The theme still works for this page view if storage is unavailable.
    }
    applyTheme();
  });

  media.addEventListener?.("change", () => {
    if (preference === "system") applyTheme();
  });

  applyTheme();
})();