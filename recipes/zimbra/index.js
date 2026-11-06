module.exports = Vigie =>
  class Zimbra extends Vigie {
    async validateUrl() {
      return true;
    }
  };
