function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const elements = document.querySelectorAll('.CxUIE, .unread');
    let count = 0;

    for (const element of elements) {
      if (element.querySelectorAll('*[data-icon="muted"]').length === 0) {
        count += 1;
      }
    }

    // set Vigie badge
    Vigie.setBadge(count);
  };

  // check for new messages every second and update Vigie badge
  Vigie.loop(getMessages);

  // inject Vigie.css stylesheet
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
