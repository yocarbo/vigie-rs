function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const unreadText =
      document
        .querySelector(
          '.inbox-list-container .panel-content .option-item:last-child .item-unread-num',
        )
        ?.textContent?.trim() ?? '';

    const unreadCount = Number.parseInt(unreadText.replace(/\D/g, ''), 10) || 0;

    Vigie.setBadge(unreadCount, 0);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
