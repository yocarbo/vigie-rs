function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const games = document.querySelector('.TurnIndicator');
    const chat_messages = document.querySelector('.ChatIndicator .count');
    const notifications = document.querySelector(
      '.NotificationIndicator .count',
    );
    const indirect =
      Number.parseInt(notifications.textContent) +
      Number.parseInt(chat_messages.textContent);
    const direct = Number.parseInt(games.textContent);
    Vigie.setBadge(direct, indirect);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
