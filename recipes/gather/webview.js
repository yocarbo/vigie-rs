function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const element = document.querySelector(
      "[aria-label='Chat'] > div > div > p",
    );
    Vigie.setBadge(element ? Vigie.safeParseInt(element.textContent) : 0);
  };

  Vigie.loop(getMessages);
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
