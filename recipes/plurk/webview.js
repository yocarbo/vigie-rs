function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let direct = 0;

    const np = document.querySelector('#noti_np_count');
    const re = document.querySelector('#noti_re_count');

    if (np) {
      direct += Vigie.safeParseInt(np.textContent);
    }
    if (re) {
      direct += Vigie.safeParseInt(re.textContent);
    }

    Vigie.setBadge(direct);
  };

  Vigie.loop(getMessages, 10_000);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
