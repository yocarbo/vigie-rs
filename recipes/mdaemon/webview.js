function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getMessages() {
    let direct = 0;
    let indirect = 0;
    const VigieData = document.querySelector('#VigieMessages').dataset;
    if (VigieData) {
      direct = VigieData.direct;
      indirect = VigieData.indirect;
    }

    Vigie.setBadge(direct, indirect);
  }

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
  Vigie.loop(getMessages);
};
