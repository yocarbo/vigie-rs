module.exports = Vigie =>
  class Jitsi extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replaceAll(/(Vigie|Electron)\/\S+ \([^)]+\)/g, '')
        .trim();
    }
  };
