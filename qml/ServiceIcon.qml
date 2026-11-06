// Icône d'un service dans la barre latérale : case fixe (petite, normale ou grande), nom facultatif,
// badge, menu du clic droit, glisser-déposer pour réordonner.
import QtQuick
import QtQuick.Controls
import Vigie

Item {
    id: cell
    required property var app
    required property string sid
    required property string json
    required property int direct
    required property int indirect
    required property string favicon
    required property string avatar
    readonly property var svc: JSON.parse(json)
    readonly property string logo: app.info(svc).icon || ""
    readonly property bool selected: sid === app.current
    readonly property bool disabled: !!svc.disabled
    readonly property bool hidden: disabled && !app.settings.show_disabled
    readonly property bool badge: app.showsBadge(svc) && (direct > 0 || indirect > 0)

    function t(text) {
        return app.t(text)
    }

    width: app.cellWidth
    height: hidden ? 0 : app.cellHeight
    visible: !hidden
    z: drag.active ? 10 : 0

    // Déposer une autre icône ici la met à cette place.
    DropArea {
        anchors.fill: parent
        keys: ["vigie-service"]
        onDropped: drop => cell.app.moveService(drop.source.sid, cell.sid)
    }

    Rectangle {
        id: tile
        readonly property string sid: cell.sid
        width: cell.width
        height: cell.height
        radius: 12
        color: cell.selected ? Qt.alpha(palette.highlight, 0.3)
            : hover.hovered ? Qt.alpha(palette.windowText, 0.08) : "transparent"
        Drag.active: drag.active
        Drag.source: tile
        Drag.keys: ["vigie-service"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        // Case fixe : icône donnée par la recipe (workspace Slack), sinon son logo, sinon favicon du
        // site, sinon initiales.
        ServiceLogo {
            id: box
            size: cell.app.iconSize
            name: cell.svc.name
            source: cell.avatar || cell.logo || cell.favicon
            rounded: !!cell.avatar
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            opacity: cell.disabled ? 0.35 : 1
        }

        // Nom sous l'icône (option).
        Label {
            visible: cell.app.settings.show_names
            anchors.top: box.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 4
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: cell.svc.name
            font.pixelSize: 10
            opacity: cell.disabled ? 0.5 : 0.85
        }

        // Badge : nombre de non-lus directs, ou point pour les indirects.
        Rectangle {
            visible: cell.badge
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 3
            height: 18
            width: cell.direct > 0 ? Math.max(18, count.implicitWidth + 8) : 10
            radius: height / 2
            color: cell.direct > 0 ? "#e01b24" : "#3584e4"
            Label {
                id: count
                anchors.centerIn: parent
                visible: cell.direct > 0
                text: cell.direct > 99 ? "99+" : cell.direct
                color: "white"
                font.pixelSize: 11
                font.bold: true
            }
        }

        // Notifications ou son coupés, service en veille prolongée.
        Label {
            visible: !!cell.svc.mute_notifications || !!cell.svc.mute_sound
            anchors.left: parent.left
            anchors.top: box.bottom
            anchors.topMargin: -12
            anchors.leftMargin: 3
            text: cell.svc.mute_notifications ? "🔕" : "🔇"
            font.pixelSize: 11
        }

        HoverHandler {
            id: hover
        }
        TapHandler {
            onTapped: cell.app.current = cell.sid
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: menu.popup()
        }
        // Clic gauche maintenu : on déplace l'icône sur une autre pour prendre sa place.
        DragHandler {
            id: drag
            xAxis.enabled: false
            onActiveChanged: {
                if (!active) {
                    tile.Drag.drop()
                    tile.y = 0
                }
            }
        }

        ToolTip.visible: hover.hovered && !drag.active && !cell.app.settings.show_names
        ToolTip.delay: 500
        ToolTip.text: cell.svc.name
    }

    Menu {
        id: menu
        MenuItem {
            text: cell.t("Notifications")
            checkable: true
            checked: !cell.svc.mute_notifications
            onTriggered: cell.app.setFlag(cell.sid, "mute_notifications", !checked)
        }
        MenuItem {
            text: cell.t("Son")
            checkable: true
            checked: !cell.svc.mute_sound
            onTriggered: cell.app.setFlag(cell.sid, "mute_sound", !checked)
        }
        MenuItem {
            text: cell.t("Compter dans le total (tray)")
            checkable: true
            checked: !cell.svc.exclude_from_total
            onTriggered: cell.app.setFlag(cell.sid, "exclude_from_total", !checked)
        }
        MenuItem {
            text: cell.t("Veille prolongée")
            checkable: true
            checked: !!cell.svc.hibernate
            onTriggered: cell.app.setFlag(cell.sid, "hibernate", checked)
        }
        MenuSeparator {}
        MenuItem {
            text: cell.t("Ouvrir dans une fenêtre séparée")
            enabled: !cell.disabled
            onTriggered: cell.app.views[cell.sid].detach()
        }
        MenuItem {
            text: cell.t("Recharger")
            enabled: !cell.disabled
            onTriggered: cell.app.views[cell.sid].reload()
        }
        MenuItem {
            text: cell.disabled ? cell.t("Activer le service") : cell.t("Désactiver le service")
            onTriggered: cell.app.setFlag(cell.sid, "disabled", !cell.disabled)
        }
        MenuSeparator {}
        MenuItem {
            text: cell.t("Modifier…")
            onTriggered: cell.app.editService(cell.sid)
        }
    }
}
