function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const element = document.querySelector('.notification-count');
    Vigie.setBadge(
      element ? Vigie.safeParseInt(element.textContent.match(/\d+/)[0]) : 0,
    );
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
