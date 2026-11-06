module.exports = Vigie =>
  class Instagram extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replace(
          /\(Macintosh; Apple macOS [^)]+\)/,
          '(Macintosh; Intel Mac OS X 10_15_7)',
        )
        .replace(/\b(?:Vigie|Electron)\/\S+/g, '')
        .replace(/\s{2,}/g, ' ')
        .trim();
    }
  };
