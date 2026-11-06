module.exports = Vigie =>
  class Threads extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replaceAll(/(Vigie|Electron)\/\S+ \([^)]+\)/g, '')
        .trim();
    }
  };
