function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const updates = Vigie.safeParseInt(
      document.querySelector('i#sr-last-counter').textContent,
    );
    let messages = 0;
    const elements = document.querySelectorAll('.chat-counter:not(.d-none)');
    for (const element of elements) {
      messages += Vigie.safeParseInt(element.textContent);
    }

    Vigie.setBadge(messages, updates);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
