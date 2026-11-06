function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = function getMessages() {
    const notificationsCounter = document.querySelector(
      '.js-notificationsCounter',
    );
    Vigie.setBadge(Vigie.safeParseInt(notificationsCounter.textContent));
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
