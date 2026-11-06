// Recipe de test des sessions : #set pose un cookie ; le badge vaut 1 si le cookie est visible.
module.exports = Vigie => {
  if (location.hash === '#set') document.cookie = 'vigie_rs=1; path=/; max-age=120';
  Vigie.loop(() => Vigie.setBadge(document.cookie.includes('vigie_rs=1') ? 1 : 0));
};
