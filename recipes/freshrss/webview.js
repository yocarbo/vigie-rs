function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = function getMessages() {
    // Initialize empty vars
    let unread = 0;
    let match = [];
    // Define RegExp to replace occasionally &nbsp
    const re = new RegExp(String.fromCodePoint(160), 'g');
    // Get value of <title> tag where in case of new feed elements the number of elements appear
    const titleValue = document.querySelector('title').text.replaceAll(re, '');
    // Extract the number from the tag
    match = titleValue.match(/[\d\s]+/);
    // Some logic to handle the match groups
    unread = match !== null && match.length > 0 ? match[0] : 0;
    // Set unread msgs badge
    Vigie.setBadge(Number.parseInt(unread, 10));
  };

  const loopFunc = () => {
    getMessages();
  };

  Vigie.loop(loopFunc);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
