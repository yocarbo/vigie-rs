module.exports = Vigie =>
  class Gotomeeting extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent.replaceAll(
        /(Vigie|Electron)\/\S+ \([^)]+\)/g,
        '',
      );
    }
  };
