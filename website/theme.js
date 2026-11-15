// Apply the saved appearance before the stylesheet loads.
(() => {
  let preference = 'system';
  try {
    const saved = localStorage.getItem('ejson-website-theme');
    if (['light', 'dark', 'system'].includes(saved)) preference = saved;
  } catch {}
  const theme = preference === 'system'
    ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
    : preference;
  document.documentElement.dataset.theme = theme;
  document.documentElement.dataset.themePreference = preference;
  const logo = theme === 'dark' ? 'logo-on-light.png' : 'logo-on-dark.png';
  document.querySelector('[data-theme-icon]')?.setAttribute('href', `assets/${logo}`);
})();
