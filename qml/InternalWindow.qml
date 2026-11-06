// Fenêtre ouverte par un service dans l'app (connexion OAuth, appel…), avec sa session et window.opener.
import QtQuick
import QtQuick.Controls
import QtWebEngine
import Vigie

ApplicationWindow {
    id: win
    required property var app
    required property var service
    required property WebEngineProfile profile
    property alias web: web

    width: 1000
    height: 720
    visible: true
    title: web.title || service.name

    WebEngineView {
        id: web
        anchors.fill: parent
        profile: win.profile
        audioMuted: win.app.muted || !!win.service.mute_sound
        onWindowCloseRequested: win.close()
        onPermissionRequested: permission => win.app.askPermission(win.service, permission)
        onNewWindowRequested: request => win.app.newWindow(win.service, win.profile, request)
        onFullScreenRequested: request => {
            request.accept()
            win.visibility = request.toggleOn ? Window.FullScreen : Window.Windowed
        }
    }

    onClosing: destroy()
}
