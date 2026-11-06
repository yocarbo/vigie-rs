function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const unreadEl = document.querySelector('a[data-page="unread"]');
    if (unreadEl == null) return Vigie.setBadge(0);

    const matches = unreadEl.textContent.match(/Unread\s+\((\d+)\)/);
    if (matches == null) return Vigie.setBadge(0);

    Vigie.setBadge(Number(matches[1]));
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));

  // only reload page if not reading an entry or in settings

  if (
    window.location.pathname.includes('/entry/') ||
    window.location.pathname == '/settings'
  ) {
    return;
  }

  const refreshMinutes = 5;

  setTimeout(
    () => {
      window.location.reload();
    },
    1000 * 60 * refreshMinutes,
  );
};
