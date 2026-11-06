function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const directMessages = document.querySelectorAll(
      '.buffer.conversation.active.unread.activeBadge',
    ).length;
    const indirectMessages = document.querySelectorAll(
      '.buffer.channel.active.unread',
    ).length;

    Vigie.setBadge(directMessages, indirectMessages);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
