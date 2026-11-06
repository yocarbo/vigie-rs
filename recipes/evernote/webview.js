function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const inbox = document.querySelector(
      '.topbar-notificationsButton.has-newNotifications',
    );
    const passiveCount = inbox === null ? 0 : 1;
    Vigie.setBadge(0, passiveCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'css', 'franz.css'));
};
