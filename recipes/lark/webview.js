function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const ele = document.querySelectorAll(
      '.larkc-badge-count.navbarMenu-badge',
    );
    if (ele.length === 0) {
      Vigie.setBadge(0);
      return;
    }
    Vigie.setBadge(ele[0].textContent);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
