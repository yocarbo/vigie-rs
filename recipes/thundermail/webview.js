function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  Vigie.loop(() => {
    const e = document.querySelector(
      '.app-toggle-button[aria-label="Mail"] > .app-spaces__badge',
    );
    const direct = e ? +e.textContent : 0;
    Vigie.setBadge(direct);
  });

  Vigie.handleDarkMode(enabled => {
    const button = document.querySelector('button.theme-toggle');
    if (!button) {
      return;
    }
    if (
      // if button reads “switch to <mode-we-want>”, we click it.
      (enabled && button.getAttribute('aria-label').includes('dark')) ||
      (!enabled && button.getAttribute('aria-label').includes('light'))
    ) {
      button.click();
    }
  });

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
