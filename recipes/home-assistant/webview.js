function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const badges = document
      .querySelector('home-assistant')
      .shadowRoot.querySelector('home-assistant-main')
      .shadowRoot.querySelector('ha-sidebar')
      .shadowRoot.querySelectorAll('.notification-badge');
    if (badges.length > 0) {
      const count = Vigie.safeParseInt(
        badges[0].textContent.replaceAll(/[^\p{N}]/gu, ''),
      );
      Vigie.setBadge(count);
    } else {
      Vigie.setBadge(0);
    }
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
