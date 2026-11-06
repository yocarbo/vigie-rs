function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let directCount = 0;
    let indirectCount = 0;

    const messageCountElement = document.querySelector('#Message-umi');
    if (messageCountElement) {
      directCount = Vigie.safeParseInt(messageCountElement.textContent);
    }

    const unreadChats = document.querySelectorAll('.has-unread');
    // unreadChats includes direct messages - do not count them
    indirectCount = unreadChats.length - directCount;

    Vigie.setBadge(directCount, indirectCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
