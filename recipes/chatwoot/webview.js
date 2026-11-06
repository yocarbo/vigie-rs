function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = function getMessages() {
    const unreadBadges = document.querySelectorAll('span.unread');
    const unreadBadgesArray = [...unreadBadges];
    const unreadMessagesCount = unreadBadgesArray.reduce(
      (previousValue, currentBadge) =>
        previousValue + Vigie.safeParseInt(currentBadge.textContent),
      0,
    );
    Vigie.setBadge(unreadMessagesCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
