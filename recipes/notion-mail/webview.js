function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  // TODO: If your Notion Mail service has unread messages, uncomment these lines to implement the logic for updating the badges
  const getMessages = () => {
    let inboxCount = 0;
    inboxCount = document.querySelectorAll('.jnEPWk')[0]
      ? Vigie.safeParseInt(
          document.querySelectorAll('.jnEPWk')[0].textContent,
        )
      : 0;

    Vigie.setBadge(inboxCount, 0);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
