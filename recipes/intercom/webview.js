function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const numMessages = Vigie.safeParseInt(
      document.querySelector(
        '.left-nav [data-content="Inbox"] .unread__container .unread',
      ).textContent,
    );
    Vigie.setBadge(numMessages);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
