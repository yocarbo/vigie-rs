function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getTasks() {
    let incompleteCount = 0;

    const countEls = document.querySelectorAll(
      '.AppSidebarGroupsItems__item__link[href^="/tasks/lists/"] .AppSidebarGroupsItems__item__badge > .AppSidebarGroupsItems__item__badge__count > div',
    );

    if (countEls.length > 0) {
      for (const el of countEls) {
        incompleteCount += Vigie.safeParseInt(el.textContent);
      }
    }

    Vigie.setBadge(incompleteCount);
  }

  Vigie.loop(getTasks);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
