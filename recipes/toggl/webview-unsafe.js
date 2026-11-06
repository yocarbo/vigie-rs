// only try to update badge once Vigie API has finished loading
if (window.vigie !== undefined && window.vigie.setBadge !== undefined) {
  const timerRunning =
    window.toggl !== undefined &&
    !!window.toggl.store.getState().view.timer.timeEntry.start;

  // Treat running timer as a "non-direct" notification (default blue dot instead of urgent red "1")
  window.vigie.setBadge(0, timerRunning ? 1 : 0);
}
