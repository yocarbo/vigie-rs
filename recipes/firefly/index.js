module.exports = Vigie =>
  class Firefly extends Vigie {
    buildUrl(url) {
      return `${url}/`;
    }
  };
