function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const hasNotifications = document
      .querySelector('#notifications-link .badge')
      .classList.contains('visible');
    Vigie.setBadge(0, hasNotifications ? 1 : 0);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
