module.exports = Vigie =>
  class Fluxer extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent.replace(
        /(Vigie|Electron)\/\S+ \([^)]+\)/g,
        '',
      );
    }
  };
