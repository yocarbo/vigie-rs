function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getUnreadEntries() {
    const element = document.querySelector(
      'a[href="/unread/list"]>span.items-number',
    );
    if (element) {
      const parsedValue = Vigie.safeParseInt(element.textContent);
      Vigie.setBadge(parsedValue);
    }
  }

  const loopFunc = () => {
    getUnreadEntries();
  };

  Vigie.loop(loopFunc);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
