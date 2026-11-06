function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const elementNotify = document.querySelectorAll('.notify');
    const elementFeed = document.querySelectorAll(
      '.unreadCounter.ng-binding.ng-scope',
    );

    let countNotify = 0;
    let countFeed = 0;

    for (const element of elementNotify) {
      const splitText = element.title.split(':');
      countNotify += Vigie.safeParseInt(splitText[1]);
    }

    for (const element of elementFeed) {
      countFeed += Vigie.safeParseInt(element.textContent);
    }

    Vigie.setBadge(countNotify, countFeed);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
  Vigie.injectCSS(_path.default.join(__dirname, 'crpk-resources/fonts.css'));
};
