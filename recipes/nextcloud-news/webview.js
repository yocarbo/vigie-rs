function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const directSelector = document.querySelector(
      '.subscriptions-feed .app-navigation-entry-utils-counter',
    );
    const direct = directSelector
      ? Vigie.safeParseInt(directSelector.textContent)
      : 0;

    Vigie.setBadge(direct);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
