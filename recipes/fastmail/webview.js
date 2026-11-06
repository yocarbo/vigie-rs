function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const inbox = document.querySelector(
      '.v-MailboxSource--inbox .v-MailboxSource-badge',
    );

    const messages = inbox ? Vigie.safeParseInt(inbox.textContent) : 0;
    Vigie.setBadge(messages);
  };

  Vigie.loop(getMessages);

  Vigie.injectJSUnsafe(_path.default.join(__dirname, 'webview-unsafe.js'));
};
