// Monkey patch ServiceWorker.postMessage so that it will actually post a notification in Vigie:

function newPostMessage(options) {
  window.vigie.displayNotification(options.title, options);
}

ServiceWorker.prototype.postMessage = newPostMessage;
