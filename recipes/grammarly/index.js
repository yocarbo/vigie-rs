module.exports = Vigie =>
  class Grammarly extends Vigie {
    async validateUrl() {
      return true;
    }
  };
