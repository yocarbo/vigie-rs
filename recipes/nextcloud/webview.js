function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const direct = document
      .querySelector('#header-menu-notifications, .notifications')
      .querySelectorAll(
        '.notification-container .notification-wrapper .notification',
      ).length;

    Vigie.setBadge(direct);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
