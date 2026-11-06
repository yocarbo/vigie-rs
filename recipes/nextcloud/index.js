module.exports = Vigie =>
  class Nextcloud extends Vigie {
    buildUrl(url) {
      return `${url}/`;
    }
  };
