function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    // This selects the first folder (the inbox and reads its unread messages count)
    const inboxField = document.querySelector('.ws-tree-node-content');
    const inboxCountField = inboxField.querySelector('.ws-tree-node-badge');
    const inboxCountText = inboxCountField ? inboxCountField.textContent : null;
    const inboxCount = inboxCountText
      ? Vigie.safeParseInt(inboxCountText)
      : 0;

    let unimportantCount = 0;

    if (inboxCount === 0) {
      // This selects the first folder with an unread message count.
      // The actaul count and the total of all other folders is not needed as the badge has no number.
      const totalCountField = document.querySelector('.ws-tree-node-badge');
      const totalCountText = totalCountField
        ? totalCountField.textContent
        : null;
      unimportantCount = totalCountText
        ? Vigie.safeParseInt(totalCountText)
        : 0;
    }

    Vigie.setBadge(inboxCount, unimportantCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
