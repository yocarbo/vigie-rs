function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let count = 0;

    const counters = document.querySelectorAll(
      '.surface-control-component .item-counter, .surface-control-component .view-item-counter',
    );

    for (const counter of counters) {
      count += Vigie.safeParseInt(counter.textContent);
    }

    Vigie.setBadge(count);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
