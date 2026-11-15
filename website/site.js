const themeSelect = document.querySelector('[data-theme-select]');
const systemTheme = matchMedia('(prefers-color-scheme: dark)');
let themePreference = document.documentElement.dataset.themePreference || 'system';

function applyTheme() {
  const theme = themePreference === 'system' ? (systemTheme.matches ? 'dark' : 'light') : themePreference;
  document.documentElement.dataset.theme = theme;
  document.documentElement.dataset.themePreference = themePreference;
  const logo = theme === 'dark' ? 'logo-on-light.png' : 'logo-on-dark.png';
  document.querySelector('[data-theme-icon]')?.setAttribute('href', `assets/${logo}`);
  if (themeSelect) themeSelect.value = themePreference;
  document.querySelectorAll('[data-screenshot]').forEach(link => {
    const name = link.dataset.screenshot;
    const asset = name === 'workbench' ? `workbench-${theme}` : `${name}${theme === 'dark' ? '-dark' : ''}`;
    link.href = `assets/${asset}.png`;
    link.querySelector('img').src = `assets/${asset}.webp`;
  });
  document.querySelectorAll('meta[name="theme-color"]').forEach(meta => {
    meta.content = theme === 'dark' ? '#10151e' : '#f7f9fc';
  });
  if (lightbox?.open) displayScreenshot(activeScreenshot);
}

if (themeSelect) {
  themeSelect.addEventListener('change', () => {
    themePreference = themeSelect.value;
    try { localStorage.setItem('ejson-website-theme', themePreference); } catch {}
    applyTheme();
  });
}
systemTheme.addEventListener('change', () => {
  if (themePreference === 'system') applyTheme();
});
window.addEventListener('storage', event => {
  if (event.key !== 'ejson-website-theme' && event.key !== null) return;
  themePreference = ['light', 'dark'].includes(event.newValue) ? event.newValue : 'system';
  applyTheme();
});

const lightbox = document.querySelector('.lightbox');
const screenshots = [...document.querySelectorAll('[data-zoom]')];
let activeScreenshot = 0;
function displayScreenshot(index) {
  activeScreenshot = (index + screenshots.length) % screenshots.length;
  const link = screenshots[activeScreenshot];
  const image = lightbox.querySelector('img');
  image.src = link.href;
  image.alt = link.querySelector('img').alt;
  lightbox.querySelector('#lightbox-caption').textContent = link.dataset.caption;
  lightbox.querySelector('[data-original]').href = link.href;
}
screenshots.forEach((link, index) => link.addEventListener('click', event => {
  if (!lightbox || typeof lightbox.showModal !== 'function' || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  event.preventDefault();
  displayScreenshot(index);
  lightbox.showModal();
}));
if (lightbox) {
  lightbox.querySelector('[data-close]').addEventListener('click', () => lightbox.close());
  lightbox.querySelector('[data-prev]').addEventListener('click', () => displayScreenshot(activeScreenshot - 1));
  lightbox.querySelector('[data-next]').addEventListener('click', () => displayScreenshot(activeScreenshot + 1));
  lightbox.addEventListener('click', event => { if (event.target === lightbox) lightbox.close(); });
  lightbox.addEventListener('keydown', event => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      displayScreenshot(activeScreenshot + (event.key === 'ArrowRight' ? 1 : -1));
    }
  });
}

applyTheme();

const filmPlayer = document.querySelector('[data-film-player]');
if (filmPlayer) {
  const video = filmPlayer.querySelector('video');
  const playButton = filmPlayer.querySelector('[data-film-play]');
  video.controls = false;
  playButton.hidden = false;
  playButton.addEventListener('click', () => {
    playButton.hidden = true;
    video.play().catch(() => {
      video.controls = true;
      playButton.hidden = false;
      video.focus();
    });
  });
  video.addEventListener('play', () => {
    video.controls = true;
    playButton.hidden = true;
  });
  video.addEventListener('ended', () => {
    video.controls = false;
    playButton.hidden = false;
  });
}
