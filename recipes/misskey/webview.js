function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    // check notification badge for Vigie badge
    const hasNotification = !!document.querySelector(
      '#app div.notifications > button > i.circle',
    );
    Vigie.setBadge(0, hasNotification ? 1 : 0);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
