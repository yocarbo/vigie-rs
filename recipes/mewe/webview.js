function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const calculateTotalDirectMessages = () =>
    [...document.querySelectorAll('.chats-list-element')]
      .map(el =>
        Vigie.safeParseInt(
          el.querySelector('.m-indicator .number').textContent,
        ),
      )
      .reduce((curr, prev) => curr + prev, 0);

  Vigie.loop(() => Vigie.setBadge(calculateTotalDirectMessages()));

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
