module.exports = Vigie =>
  class Mattermost extends Vigie {
    async validateUrl(url) {
      try {
        const resp = await window.fetch(url, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
          },
        });
        return resp.status.toString().startsWith('2');
      } catch (error) {
        console.error(error);
      }

      return false;
    }
  };
