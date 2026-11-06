module.exports = Vigie => {
  class Mastodon extends Vigie {
    validateServer(URL) {
      const api = `${URL}`;
      return new Promise((resolve, reject) => {
        $.get(api, () => {
          resolve();
        }).fail(reject);
      });
    }
  }

  return Mastodon;
};
