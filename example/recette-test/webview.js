// Recipe de test au format des recipes Vigie compilées (babel → CommonJS).
const _path = _interopRequireDefault(require('path'));
function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

module.exports = Vigie => {
  Vigie.loop(() => Vigie.setBadge(document.querySelectorAll('.unread').length));
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
