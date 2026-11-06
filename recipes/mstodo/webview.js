function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const elements = document.querySelectorAll('.taskItem');
    let count = 0;

    for (const element of elements) {
      if (element.querySelectorAll('.completed').length === 0) {
        count += 1;
      }
    }

    // set Vigie badge
    Vigie.setBadge(count);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
