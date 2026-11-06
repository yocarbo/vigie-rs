const path = require('path');

module.exports = Vigie => {
  window.addEventListener('gotify-vigie-badge', event => {
    Vigie.setBadge(event.detail?.count || 0, 0);
  });

  Vigie.injectJSUnsafe(path.join(__dirname, 'badge.js'));
  Vigie.loop(() => {
    window.dispatchEvent(new CustomEvent('gotify-vigie-poll'));
  });
};
