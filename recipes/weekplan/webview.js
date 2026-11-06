function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  const getMessages = () => {
    const events = document
      .querySelectorAll('.today')[0]
      .querySelectorAll('.list')[0]
      .querySelectorAll('.task-list')[0]
      .querySelectorAll('.event-section')[0]
      .querySelectorAll('.droppable')[0].children[0].childElementCount;
    const tasks = document
      .querySelectorAll('.today')[0]
      .querySelectorAll('.list')[0]
      .querySelectorAll('.task-list')[0]
      .querySelectorAll('.task-section')[0]
      .querySelectorAll('.droppable')[0].children[0].childElementCount;

    Vigie.setBadge(events + tasks);
  };

  Vigie.loop(getMessages);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
