function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let unreadCount = 0;
    // Take the counter element from the "Inbox" folder
    for (const counterElement of document.querySelectorAll(
      '[data-testid="navigation-link:inbox"] [data-testid="navigation-link:unread-count"]',
    )) {
      const unreadCounter = Vigie.safeParseInt(counterElement.textContent);
      unreadCount = Math.max(unreadCount, unreadCounter);
    }

    Vigie.setBadge(unreadCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
