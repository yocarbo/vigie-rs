function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const directCountSelector = [
      ...document.querySelectorAll('[data-region="count-container"]'),
    ];
    const totalMessageCount = directCountSelector.reduce(
      (count, item) => count + Vigie.safeParseInt(item.textContent),
      0,
    );

    Vigie.setBadge(totalMessageCount, 0);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
