module.exports = Vigie =>
  class Outlook extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replaceAll(/(Vigie|Electron)\/\S+ \([^)]+\)/g, '')
        .trim();
    }
  };
