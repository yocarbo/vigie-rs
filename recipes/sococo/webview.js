function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const indirect = document.querySelectorAll('.new-messages');
    let direct = 0;
    for (const badge of document.querySelectorAll('.people-pane .badge')) {
      direct += Vigie.safeParseInt(badge.textContent);
    }
    Vigie.setBadge(direct, indirect);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
