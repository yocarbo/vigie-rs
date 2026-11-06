function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getMessages() {
    const directMatches = document
      .querySelector('title')
      .textContent.match('(?<=\\[)\\d+(?=])');
    Vigie.setBadge(
      Vigie.safeParseInt(directMatches === null ? 0 : directMatches[0]),
      document
        .querySelector('.mx_SpaceTreeLevel')
        .querySelectorAll('.mx_NotificationBadge_dot').length,
    );
  }

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
