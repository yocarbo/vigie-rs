function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const unreadSpan = document.querySelector(
      'span.flag-count.message-count.unread-count',
    );
    let directCount = 0;
    if (unreadSpan) {
      directCount = Vigie.safeParseInt(unreadSpan.textContent);
    }
    Vigie.setBadge(directCount);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
