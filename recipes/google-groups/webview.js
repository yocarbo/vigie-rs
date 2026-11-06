function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let countImportant = 0;
    const unReadConversationCount = document.querySelectorAll('.NHlkZc');
    if (unReadConversationCount.length > 0) {
      countImportant = Vigie.safeParseInt(
        unReadConversationCount[0].textContent,
      );
    }
    Vigie.setBadge(countImportant, 0);
  };
  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
