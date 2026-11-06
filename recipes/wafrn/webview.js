module.exports = Vigie => {
  const getMessages = () => {
    const messageBadge = document.querySelector('#mat-badge-content-0');
    const parsedCount = Vigie.safeParseInt(messageBadge.textContent);
    if (parsedCount) {
      Vigie.setBadge(parsedCount, 0);
    } else {
      Vigie.setBadge(0, 0);
    }
  };
  Vigie.loop(getMessages);
};
