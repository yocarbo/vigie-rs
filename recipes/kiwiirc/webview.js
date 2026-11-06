function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = function getMessages() {
    // eslint-disable-next-line no-undef
    const unreadChannelsCount = kiwi.state.networks.reduce((count, network) => {
      // eslint-disable-next-line no-param-reassign
      return (count += network.buffers.filter(buffer => {
        return !buffer.name.startsWith('*') && buffer.flags.unread !== 0;
      }).length);
    }, 0);

    // eslint-disable-next-line no-undef
    const mentionedChannelsCount = kiwi.state.networks.reduce(
      (count, network) => {
        // eslint-disable-next-line no-param-reassign
        return (count += network.buffers.filter(buffer => {
          return (
            !buffer.name.startsWith('*') &&
            buffer.flags.unread !== 0 &&
            buffer.flags.highlight
          );
        }).length);
      },
      0,
    );

    // set Vigie badges
    Vigie.setBadge(mentionedChannelsCount, unreadChannelsCount);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
