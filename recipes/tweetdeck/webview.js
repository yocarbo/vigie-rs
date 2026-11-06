function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  // Tweetdeck redirect fix
  Vigie.ipcRenderer.on('redirect-url', (event, url) => {
    window.location.assign(url);
  });

  const getMessages = () => {
    const elements = document.querySelectorAll('.msg-unread-count');
    let count = 0;
    if (elements[0]) {
      count = Vigie.safeParseInt(elements[0].textContent);
    }

    Vigie.setBadge(count);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
