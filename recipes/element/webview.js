function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getMessages() {
    const matches = document
      .querySelector('title')
      .textContent.match('(?<=\\[)\\d+(?=])');
    const directCount = Vigie.safeParseInt(matches === null ? 0 : matches[0]);
    const indirectCount = document
      .querySelector('.mx_SpaceTreeLevel')
      .querySelectorAll('.mx_NotificationBadge_dot').length;
    Vigie.setBadge(directCount, indirectCount);
  }

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
