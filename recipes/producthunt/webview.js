function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const notificationsSelector = document.querySelector(
    '[class*=header_] [class*=content_] [class*=actions_] [class*=notificationsButton_]',
  );

  const getMessages = () => {
    if (notificationsSelector) {
      Vigie.setBadge(notificationsSelector.textContent);
    }
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
