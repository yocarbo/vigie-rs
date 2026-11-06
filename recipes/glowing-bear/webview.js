function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const indirectElements = document.querySelectorAll('.badge:not(.danger)');
    const direct = document.querySelectorAll('.badge.danger').length - 1;
    let indirect = -1;
    for (const indirectElement of indirectElements) {
      if (
        indirectElement.textContent &&
        indirectElement.textContent.length > 0
      ) {
        indirect += 1;
      }
    }
    Vigie.setBadge(direct, indirect);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
