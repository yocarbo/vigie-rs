// Monde de la page : `window.vigie`, utilisé par les scripts injectJSUnsafe des recipes. Les messages
// passent au monde isolé de la recipe par un événement du document, qui les relaie vers l'app.
(() => {
  const post = m => document.dispatchEvent(new CustomEvent('__vigie-page', { detail: JSON.stringify(m) }));
  const int = t => Math.max(Number.parseInt(String(t ?? 0), 10) || 0, 0);
  window.vigie = {
    setBadge: (direct = 0, indirect = 0) => post({ type: 'badge', direct: int(direct), indirect: int(indirect) }),
    safeParseInt: int,
    open: url => post({ type: 'open', url: String(url) }),
    // Notifications natives de Chromium : l'app les reçoit et les envoie au bureau.
    displayNotification: (title, options) => new Notification(title, options),
    setDialogTitle: () => {},
    getDisplayMediaSelector: () => {},
  };
})();
