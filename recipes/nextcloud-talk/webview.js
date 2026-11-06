function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    // With `// Legacy ` are marked those selectors that were working for some
    // Nextcloud version before 27 (24 or 25).
    const counterBubble = '.counter-bubble__counter';
    const directFromLeftSideBar = document.querySelectorAll(
      `${counterBubble}--highlighted`, // Nextcloud 27
    ).length;
    let indirect = 0;
    for (const counter of document.querySelectorAll(
      '.app-navigation-entry__counter, ' + // Legacy
        `${counterBubble}:not(${counterBubble}--highlighted)`, // Nextcloud 27
    )) {
      indirect += Vigie.safeParseInt(counter?.textContent.trim());
    }

    if (document.title.startsWith('*')) {
      indirect += 1;
    }

    Vigie.setBadge(
      // Try to use the unread conversations count retrieved from the left
      // sidebar, otherwise check Talk specific notifications
      directFromLeftSideBar > 0
        ? directFromLeftSideBar
        : Vigie.safeParseInt(
            document
              .querySelector(
                '.notifications .notification-wrapper, ' + // Legacy
                  '.notification-container .notification-wrapper', // Nextcloud 27
              )
              ?.querySelectorAll(
                '.notification[object_type="chat"], ' + // Legacy
                  '.notification[object_type="room"], ' + // Legacy
                  '.notification[data-object-type="chat"], ' + // Nextcloud 27
                  '.notification[data-object-type="room"]', // Nextcloud 27
              ).length,
          ),
      indirect,
    );
  };

  Vigie.loop(getMessages);
  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
