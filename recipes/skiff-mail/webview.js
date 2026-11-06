function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const element = document.querySelector('div[href="/mail/inbox"]');
    const matches = element.textContent.match(/\d+/);
    const unreadCount = Vigie.safeParseInt(matches ? matches[0] : 0);
    Vigie.setBadge(unreadCount);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
