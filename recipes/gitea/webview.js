function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const directCountElement = document.querySelector('.notification_count');
    let directCount = 0;
    if (directCountElement) {
      directCount = Vigie.safeParseInt(directCountElement.textContent);
    }

    Vigie.setBadge(directCount, 0);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
