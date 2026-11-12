// Micro et caméra : la question de Vigie, dans une petite fenêtre au-dessus de celle qui demande (la
// fenêtre principale, une fenêtre d'appel, un service détaché). Dans la fenêtre principale, elle
// restait cachée derrière une fenêtre d'appel (Slack), et la demande en attente : pas de micro.
// Entrée autorise, Échap ou fermer la fenêtre refuse. Le micro et la caméra ont chacun leur réponse.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

ApplicationWindow {
    id: win
    required property var app
    required property var svc
    required property var permission
    property bool answered: false

    // Demandes arrivées pendant la question, pour le même service (Slack en fait plusieurs à la fois) :
    // une seule question pour toutes.
    property var others: []
    function add(p) {
        others = others.concat(p) // nouvelle liste : le titre et les cases se mettent à jour
    }
    // Ce qui est demandé (cette demande et celles arrivées depuis) : micro, caméra, ou les deux.
    readonly property var asked: {
        const kinds = new Set()
        for (const p of [permission, ...others])
            app.mediaKinds(p).forEach(k => kinds.add(k))
        return [...kinds]
    }
    readonly property bool both: asked.length === 2
    readonly property string what: both ? app.t("le micro et la caméra")
        : asked[0] === "camera" ? app.t("la caméra") : app.t("le micro")
    // Chacun sa réponse, retenue pour le service (Qt ne la garde pas) : avec les deux demandés, les
    // cases choisissent ce qu'« Autoriser » accorde, le reste est refusé. Une demande qui inclut un
    // périphérique refusé est refusée (Qt n'en accorde pas une partie). Fermer sans répondre refuse
    // cette fois-ci seulement.
    function answer(allow) {
        answered = true
        const ok = {
            microphone: allow && (!both || micBox.checked),
            camera: allow && (!both || camBox.checked),
        }
        for (const p of [permission, ...others]) {
            if (app.mediaKinds(p).every(k => ok[k]))
                p.grant()
            else
                p.deny()
        }
        for (const k of asked)
            app.setMedia(svc.id, [k], ok[k] ? "allow" : "deny")
        close()
    }
    onClosing: {
        if (!answered) {
            for (const p of [permission, ...others])
                p.deny()
        }
        app.mediaWindows = app.mediaWindows.filter(w => w !== win)
        destroy()
    }

    title: app.t("%1 veut utiliser %2").arg(svc.name).arg(what)
    flags: Qt.Dialog
    modality: Qt.WindowModal
    width: 440
    height: column.implicitHeight + 32
    visible: true
    Component.onCompleted: {
        raise()
        requestActivate()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: win.answer(true)
    }
    Shortcut {
        sequence: "Escape"
        onActivated: win.answer(false)
    }
    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14
        Label {
            text: win.title
            font.bold: true
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        RowLayout {
            visible: win.both
            CheckBox {
                id: micBox
                checked: true
                text: win.app.t("Micro")
            }
            CheckBox {
                id: camBox
                checked: true
                text: win.app.t("Caméra")
            }
        }
        Label {
            text: win.app.t("Vigie retient ta réponse pour ce service, le micro et la caméra chacun la sienne ; tu peux la changer en modifiant le service.")
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Button {
                text: win.app.t("Refuser")
                onClicked: win.answer(false)
            }
            Button {
                text: win.app.t("Autoriser")
                highlighted: true
                onClicked: win.answer(true)
            }
        }
    }
}
