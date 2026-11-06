function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = (Vigie, settings) => {
  const getMessages = () => {
    let directCount = 0;
    const directCountPerServer = document.querySelectorAll(
      '[class*="lowerBadge_"] [class*="numberBadge_"]',
    );

    for (const directCountBadge of directCountPerServer) {
      directCount += Vigie.safeParseInt(directCountBadge.textContent);
    }

    const indirectCountPerServer =
      document.title.search('• Discord') === -1 ? 0 : 1;

    Vigie.setBadge(directCount, indirectCountPerServer);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
  Vigie.injectJSUnsafe(
    _path.default.join(__dirname, 'notification-compatibility.js'),
  );

  // TODO: See how this can be moved into the main vigie app and sent as an ipc message for opening with a new window or same Vigie recipe's webview based on user's preferences
  document.addEventListener(
    'click',
    event => {
      const link = event.target.closest('a[href^="http"]');
      const button = event.target.closest('button[title^="http"]');

      if (link || button) {
        const url = link
          ? link.getAttribute('href')
          : button.getAttribute('title');
        const skipDomains = [
          /^https:\/\/discordapp\.com\/channels\//i,
          /^https:\/\/discord\.com\/channels\//i,
        ];

        let stayInsideDiscord;
        skipDomains.every(skipDomain => {
          stayInsideDiscord = skipDomain.test(url);
          return !stayInsideDiscord;
        });

        if (!Vigie.isImage(link) && !stayInsideDiscord) {
          event.preventDefault();
          event.stopPropagation();

          if (
            // Always open file downloads in Vigie, rather than the external browser
            url.includes('discordapp.com/attachments/') ||
            settings.trapLinkClicks === true
          ) {
            window.location.href = url;
          } else {
            Vigie.openNewWindow(url);
          }
        }
      }
    },
    true,
  );
};
