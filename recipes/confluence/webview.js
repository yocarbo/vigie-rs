function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const unreadMessageCountElement = document.querySelector(
      '#notifications-anchor .badge',
    );
    const unreadMessagesCount = Vigie.safeParseInt(
      unreadMessageCountElement.textContent,
    );
    Vigie.setBadge(unreadMessagesCount, 0);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
