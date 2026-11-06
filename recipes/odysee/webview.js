function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getNotifications() {
    let unreadNotifications = 0;
    for (const notificationCounterElement of document.querySelectorAll(
      '.notification__count',
    )) {
      unreadNotifications += Vigie.safeParseInt(
        notificationCounterElement.textContent,
      );
    }

    Vigie.setBadge(unreadNotifications);
  }
  Vigie.loop(getNotifications);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
