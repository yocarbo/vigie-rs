function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    // get unread messages
    let directCount = 0;
    for (const node of document.querySelectorAll('div.unread-indicator')) {
      directCount += Vigie.safeParseInt(node.textContent);
    }

    const channelMentionCount =
      document.querySelectorAll('.mention-indicator').length;

    // set Vigie badge
    Vigie.setBadge(directCount, channelMentionCount);
  };

  Vigie.loop(getMessages);

  // Hide download message
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
