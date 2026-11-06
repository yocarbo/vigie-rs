// Wait for Vigie to initialize
if (window.vigie?.setBadge !== undefined) {
  window.vigie.setBadge(
    window.vigie.safeParseInt(window.zmfolAction?.getUnreadViewCount()) +
      window.vigie.safeParseInt(
        document.querySelector('#wms_menu_unreadchats_cnt')?.textContent,
      ),
    window.vigie.safeParseInt(
      window.zmTopBar?.topBandElements()?.notification?.children
        ?.notificationBadge?.textContent,
    ),
  );
}
