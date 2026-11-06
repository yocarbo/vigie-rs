function _interopRequireDefault(obj) {
  return obj && obj.__esModule ? obj : { default: obj };
}

const _path = _interopRequireDefault(require('path'));

module.exports = Vigie => {
  let dbCache;

  const getMessages = () => {
    if (dbCache) {
      let unreadCount = 0;
      let unreadMutedCount = 0;

      const txn = dbCache.transaction('chat', 'readonly');
      const store = txn.objectStore('chat');
      const query = store.getAll();
      query.onsuccess = event => {
        for (const chat of event.target.result) {
          if (chat.unreadCount > 0 && !chat.archive) {
            if (chat.muteExpiration != 0 || chat.isAutoMuted) {
              unreadMutedCount += chat.unreadCount;
            } else {
              unreadCount += chat.unreadCount;
            }
          }
        }

        Vigie.setBadge(unreadCount, unreadMutedCount);
      };

      query.addEventListener('error', event => {
        console.error('Loading data from database failed:', event);
      });
    } else {
      const dbsPromise = indexedDB.databases();
      dbsPromise.then(databases => {
        for (let index in databases) {
          //Wait for model-storage db to be available before calling indexedDB.open(). This is to make sure whatsapp created the model-storage DB
          if (databases[index].name === 'model-storage') {
            const request = window.indexedDB.open('model-storage');
            request.onsuccess = () => {
              dbCache = request.result;
              // This will be called when db.delete is triggered, we need to close and set dbCache to null to trigger lookup again
              dbCache.onversionchange = () => {
                dbCache.close();
                dbCache = null;
              };
            };
            request.addEventListener('error', () => {
              console.error('Opening model-storage database failed:', event);
            });
          }
        }
      });
    }
  };

  // inject webview hacking script
  Vigie.injectJSUnsafe(_path.default.join(__dirname, 'webview-unsafe.js'));

  const getActiveDialogTitle = () => {
    const element = document.querySelector('header .emoji-texttt');

    Vigie.setDialogTitle(element ? element.textContent : '');
  };

  const loopFunc = () => {
    getMessages();
    getActiveDialogTitle();
  };

  window.addEventListener('beforeunload', async () => {
    Vigie.releaseServiceWorkers();
  });

  Vigie.handleDarkMode(isEnabled => {
    if (isEnabled) {
      document.body.classList.add('dark');
    } else {
      document.body.classList.remove('dark');
    }
  });

  Vigie.loop(loopFunc);

  Vigie.injectCSS(_path.default.join(__dirname, 'service.css'));
};
