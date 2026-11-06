function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const updateBadge = function updateBadge() {
    Vigie.injectJSUnsafe(_path.default.join(__dirname, 'webview-unsafe.js'));
  };

  Vigie.loop(updateBadge);
};
