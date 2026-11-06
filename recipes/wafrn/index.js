module.exports = Vigie =>
  class Wafrn extends Vigie {
    async validateUrl(url) {
      try {
        const resp = await window.fetch(`${url}/api/`);
        const data = await resp.json();

        return data.readme.includes('wafrn');
      } catch (error) {
        console.error(error);
      }

      return false;
    }
  };
