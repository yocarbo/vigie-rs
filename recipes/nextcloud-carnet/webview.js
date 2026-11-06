function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const directSelector = document.querySelectorAll(
      '.app-navigation-entry-utils-counter.highlighted',
    );
    const direct = directSelector
      ? Vigie.safeParseInt(directSelector.length)
      : 0;

    const indirectSelector = document.querySelectorAll(
      '.app-navigation-entry-utils-counter:not(.highlighted)',
    );
    const indirect = indirectSelector
      ? Vigie.safeParseInt(indirectSelector.length)
      : 0;

    Vigie.setBadge(direct, indirect);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
