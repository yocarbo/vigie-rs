function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const unreadPrivateMessages = Vigie.safeParseInt(
      $('.messages .unread-meeps').text(),
    );
    const unreadGroupMessages = Vigie.safeParseInt(
      $('.today .unread-meeps').text(),
    );

    Vigie.setBadge(unreadPrivateMessages + unreadGroupMessages);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
