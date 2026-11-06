function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    let notifications = 0;
    let indirectNotifications = 0;

    const notificationElement = document.querySelector('#notifications_amount');
    const ticketElement = document.querySelector(
      "a[href='tickets.php'] > span",
    );
    const callElement = document.querySelector('#queue_amount');

    if (notificationElement) {
      notifications = Vigie.safeParseInt(
        notificationElement.getAttribute('datacount'),
      );
    }

    if (ticketElement !== null) {
      indirectNotifications = Vigie.safeParseInt(ticketElement.textContent);
    }

    if (callElement) {
      indirectNotifications += Vigie.safeParseInt(
        callElement.getAttribute('datacount'),
      );
    }

    Vigie.setBadge(notifications, indirectNotifications);
  };

  Vigie.loop(getMessages);
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
