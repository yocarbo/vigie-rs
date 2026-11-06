function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

window.addEventListener('load', () => {
  const title = document.querySelector('.window-title').textContent;

  if (title && title.includes('Google Chrome 36+')) {
    window.location.reload();
  }
});

module.exports = (Vigie, settings) => {
  const getMessages = () => {
    const elements = document.querySelectorAll('.CxUIE, .unread');
    let count = 0;

    for (const element of elements) {
      if (element.querySelectorAll('*[data-icon="muted"]').length === 0) {
        count += 1;
      }
    }

    Vigie.setBadge(count);
  };

  Vigie.loop(getMessages);

  window.addEventListener('beforeunload', async () => {
    Vigie.clearStorageData(settings.id, { storages: ['serviceworkers'] });
  });

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
