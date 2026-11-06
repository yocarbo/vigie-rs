module.exports = Vigie =>
  class CustomWebsite extends Vigie {
    async validateUrl() {
      return true;
    }
  };
