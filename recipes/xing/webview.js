function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getUnreadConversations() {
    Vigie.setBadge(
      document.querySelector('#unread-conversations').textContent,
    );
  }

  Vigie.loop(getUnreadConversations);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
