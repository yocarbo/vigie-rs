function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const notifications = document.querySelector(
      '.c-notifications-dropdown__count',
    );
    if (notifications) {
      Vigie.setBadge(notifications.textContent);
    }
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
