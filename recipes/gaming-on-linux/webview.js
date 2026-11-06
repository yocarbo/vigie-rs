function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  function getNotificationCount() {
    let notifications = document.querySelector(
      '#normal_notifications > a:nth-child(1) > span',
    ).innerHTML;
    return Vigie.safeParseInt(notifications);
  }

  function getMessageCount() {
    let messages = document.querySelector('#pm_counter').innerHTML;
    return Vigie.safeParseInt(messages);
  }

  const updateMessageCount = () => {
    let count = getNotificationCount() + getMessageCount();
    Vigie.setBadge(count);
  };

  const loopRoutine = () => {
    updateMessageCount();
  };

  Vigie.loop(loopRoutine);
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
