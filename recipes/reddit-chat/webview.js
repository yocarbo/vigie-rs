function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  // Regular expression for (*) or (1), will extract the asterisk or the number
  const titleRegEx = /^\(([\d*])\)/;
  const getMessages = function unreadCount() {
    let directCount = 0;
    let indirectCount = 0;

    const matchArr = document.title.match(titleRegEx);
    if (matchArr) {
      if (matchArr[1] === '*') {
        indirectCount = 1;
      } else {
        directCount = Number(matchArr[1]);
      }
    }

    Vigie.setBadge(directCount, indirectCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
