module.exports = Vigie =>
  class Discord extends Vigie {
    overrideUserAgent() {
      return window.navigator.userAgent
        .replace('(KHTML, like Gecko)', '(KHTML, like Gecko) discord/0.0.250')
        .replace('Electron', 'Discord')
        .replace('Vigie', 'Discord')
        .replace('Apple Mac OS X', 'Intel Mac OS X')
        .replace('Apple macOS', 'Intel Mac OS X');
    }
  };
