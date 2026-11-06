function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const hasUnreads = !!document.querySelector(
      '.unread-icon,.contact aside p',
    );
    const count = document
      .querySelectorAll('.contact aside p')
      .values()
      .map(el => Vigie.safeParseInt(el.textContent) || 1)
      .reduce((a, b) => a + b, 0);

    Vigie.setBadge(count || +hasUnreads);
  };

  const getDialogTitle = () => {
    const username = location.pathname.match(/^\/inbox\/([^/]+)/)?.[1];
    Vigie.setDialogTitle(username ?? null);
  };

  Vigie.loop(() => {
    getMessages();
    getDialogTitle();
  });

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
