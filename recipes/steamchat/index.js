module.exports = Vigie =>
  class SteamChat extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replaceAll(/(Vigie|Electron)\/\S+ \([^)]+\)/g, '')
        .trim();
    }
  };
