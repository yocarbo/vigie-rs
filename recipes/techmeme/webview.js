function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = (Vigie, settings) => {
  document.addEventListener(
    'click',
    event => {
      const link = event.target.closest('a[href^="http"]');
      const button = event.target.closest('button[title^="http"]');

      if (link || button) {
        const url = link
          ? link.getAttribute('href')
          : button.getAttribute('title');

        if (!Vigie.isImage(link)) {
          event.preventDefault();
          event.stopPropagation();

          if (settings.trapLinkClicks === true || url.includes('techmeme')) {
            window.location.href = url;
          } else {
            Vigie.openNewWindow(url);
          }
        }
      }
    },
    true,
  );
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
