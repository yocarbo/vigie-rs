module.exports = Vigie => {
  const safeBadgeValue = text =>
    Vigie.safeParseInt((text || '').replace(/\D/g, '')) || 0;

  const getExplicitBadge = () => {
    const badgeNode = document.querySelector('[data-vigie-badge]');
    if (!badgeNode) return 0;

    const value = badgeNode.dataset.vigieBadge || badgeNode.textContent;
    return safeBadgeValue(value);
  };

  const getMessages = () => {
    Vigie.setBadge(getExplicitBadge(), 0);
  };

  Vigie.loop(getMessages);
};
