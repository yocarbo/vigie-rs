function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  // if the user is on googlecalendar landing page, go to the login page.
  if (
    location.hostname === 'workspace.google.com' &&
    location.href.includes('products/calendar/')
  ) {
    location.href =
      'https://accounts.google.com/AccountChooser?continue=https://calendar.google.com/u/0/';
  }

  // Style of the reminder window (webview-unsafe.js), from disk: injectCSS sets
  // textContent, which calendar.google.com's Trusted Types allow. The copy that
  // was linked from cdn.statically.io loaded but never applied, so reminders
  // opened below the page, out of sight, and their badge stayed.
  Vigie.injectCSS(_path.default.join(__dirname, 'calendar.css'));

  // Injected from disk: injectJSUnsafe only reads local files, handing the
  // source to webview.executeJavaScript (which page CSP does not apply to).
  // Passing it a URL silently injected nothing at all.
  Vigie.injectJSUnsafe(_path.default.join(__dirname, 'webview-unsafe.js'));

  Vigie.handleDarkMode(isEnabled => {
    const cssId = 'cssDarkModeWorkaround';

    if (isEnabled) {
      // Workaround for loading darkmode.css
      if (!document.querySelector(`#${cssId}`)) {
        const head = document.querySelectorAll('head')[0];
        const link = document.createElement('link');
        link.id = cssId;
        link.rel = 'stylesheet';
        link.type = 'text/css';
        link.href =
          'https://cdn.statically.io/gh/ferdium/ferdium-recipes/main/recipes/google-calendar/darkmode.css';
        link.media = 'all';
        head.append(link);
      }
    } else {
      document.querySelector(`#${cssId}`)?.remove();
    }
  });
};
