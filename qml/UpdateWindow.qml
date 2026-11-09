// Mise à jour depuis les sources (./vigie-rs update, lancé par Vigie sans terminal) : l'étape en cours
// (lignes « ==> » du script), sa sortie à la demande, puis Redémarrer ou l'échec. La fermer pendant la
// mise à jour la cache seulement : la compilation continue, « Installer » la rouvre.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vigie

ApplicationWindow {
    id: win
    required property var app
    property string log: ""
    property string step: ""
    property int code: -1 // code de sortie du script, -1 tant qu'il tourne
    readonly property bool finished: code >= 0

    function t(text) {
        return app.t(text)
    }

    // Fin du journal relue chaque seconde ; l'étape reste la dernière vue, même sortie de cette fin.
    function poll() {
        log = Backend.updateLog()
        const lines = log.split("\n")
        for (let i = lines.length - 1; i >= 0; i--) {
            if (!lines[i].startsWith("==> "))
                continue
            const m = /^==> code (\d+)$/.exec(lines[i])
            if (m) {
                code = Number(m[1])
                continue
            }
            step = lines[i].slice(4)
            break
        }
    }
    onFinishedChanged: {
        app.updateDone = code === 0
        // Lancée à ta demande : Vigie redémarre de lui-même sur la nouvelle version.
        if (code === 0 && app.updateByHand)
            return app.restartVigie()
        app.updateStatus = code === 0 ? t("Mise à jour installée : redémarre Vigie pour l'utiliser.")
            : t("La mise à jour a échoué (code %1) : voir les détails.").arg(code)
        if (code !== 0)
            details.checked = true
        show()
        raise()
    }
    Timer {
        interval: 1000
        running: !win.finished
        repeat: true
        triggeredOnStart: true
        onTriggered: win.poll()
    }
    onClosing: close => {
        if (!finished)
            return // cachée seulement
        app.updateWindow = null
        destroy()
    }

    title: t("Mise à jour de Vigie")
    flags: Qt.Dialog
    width: 600
    height: column.implicitHeight + 32
    visible: true

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            spacing: 12
            BusyIndicator {
                running: !win.finished
                visible: running
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.bold: true
                text: win.finished ? win.app.updateStatus : win.step || win.t("Démarrage…")
            }
        }
        Label {
            visible: !win.finished
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.75
            text: win.t("La compilation prend quelques minutes, et Vigie reste utilisable pendant ce temps. Si Vigie est installé dans un dossier système, une fenêtre du système te demandera le mot de passe d'administrateur.")
        }
        ScrollView {
            id: scroll
            visible: details.checked
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            TextArea {
                readOnly: true
                wrapMode: TextEdit.Wrap
                font.family: "monospace"
                font.pixelSize: 11
                text: win.log
                // Toujours la fin : les dernières lignes.
                onTextChanged: cursorPosition = length
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Button {
                id: details
                checkable: true
                flat: true
                text: win.t("Détails")
            }
            Button {
                text: win.finished ? win.t("Fermer") : win.t("Continuer en arrière-plan")
                onClicked: win.close()
            }
            Button {
                visible: win.finished && win.code === 0
                highlighted: true
                text: win.t("Redémarrer")
                onClicked: win.app.restartVigie()
            }
        }
    }
}
