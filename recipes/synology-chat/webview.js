function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}
const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  Vigie.handleDarkMode(isEnabled => {
    localStorage.setItem('theme', isEnabled ? 'dark' : 'light');
  });

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));

  Vigie.loop(() => {
    const unreadElements = document.querySelectorAll(
      '.highlight, .highlight-mention',
    );
    let unreadCount = 0;

    if (unreadElements.length > 0) {
      unreadCount = unreadElements.length;
    }

    Vigie.setBadge(unreadCount);
  });
};
