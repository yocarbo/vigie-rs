module.exports = Vigie =>
  class Jira extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replaceAll(/(Vigie|Electron)\/\S+ \([^)]+\)/g, '')
        .trim();
    }
  };
