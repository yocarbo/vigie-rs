function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let indirectCount = 0;
    const badge = document.querySelector('#numNotifs2');

    if (badge && badge.textContent) {
      indirectCount = Vigie.safeParseInt(badge.textContent);
    }

    Vigie.setBadge(0, indirectCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
