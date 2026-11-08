// Clé de sécurité (WebAuthn) d'une vue web. Qt WebEngine ne montre rien au début d'une demande, et la
// page attend en silence : la fenêtre s'ouvre dès que la page demande une clé (signalé par le script
// de Main.qml), puis sert les étapes que Qt envoie (compte, code PIN, échec au bout de 3 minutes).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

ApplicationWindow {
    id: win
    required property var app
    required property var web
    property string site
    property int pending: 0 // demandes en cours dans la page et ses cadres
    property var request: null // étape envoyée par Qt, sinon : brancher et toucher la clé
    property bool ended: false
    property int revision: 0 // Qt renvoie la même étape après un code PIN refusé

    Connections {
        target: win.request
        function onStateChanged() {
            win.revision++
            pin.text = ""
        }
    }

    readonly property int step: request ? request.state : WebEngineWebAuthUxRequest.WebAuthUxState.NotStarted
    readonly property bool selecting: step === WebEngineWebAuthUxRequest.WebAuthUxState.SelectAccount
    readonly property bool pinNeeded: step === WebEngineWebAuthUxRequest.WebAuthUxState.CollectPin
    readonly property bool failed: step === WebEngineWebAuthUxRequest.WebAuthUxState.RequestFailed
    readonly property string host: request && request.relyingPartyId || site

    function failure() {
        switch (request.requestFailureReason) {
        case WebEngineWebAuthUxRequest.RequestFailureReason.Timeout:
            return app.t("Délai dépassé.")
        case WebEngineWebAuthUxRequest.RequestFailureReason.KeyNotRegistered:
            return app.t("Cette clé n'est pas enregistrée sur ce site.")
        case WebEngineWebAuthUxRequest.RequestFailureReason.KeyAlreadyRegistered:
            return app.t("Cette clé est déjà enregistrée sur ce site.")
        case WebEngineWebAuthUxRequest.RequestFailureReason.SoftPinBlock:
        case WebEngineWebAuthUxRequest.RequestFailureReason.HardPinBlock:
            return app.t("Clé bloquée : trop de codes PIN erronés.")
        case WebEngineWebAuthUxRequest.RequestFailureReason.UserConsentDenied:
            return app.t("Demande refusée sur la clé.")
        default:
            return app.t("La clé de sécurité n'a pas pu être utilisée.")
        }
    }
    readonly property string message: {
        revision
        if (selecting)
            return app.t("Compte à utiliser sur %1 :").arg(host)
        if (pinNeeded) {
            const p = request.pinRequest
            const wrong = p.error === WebEngineWebAuthUxRequest.PinEntryError.WrongPin
            return app.t("Code PIN de la clé de sécurité, pour %1.").arg(host)
                + (wrong ? "\n" + app.t("Code refusé, %1 essai(s) restant(s).").arg(p.remainingAttempts) : "")
        }
        if (failed)
            return failure()
        if (step === WebEngineWebAuthUxRequest.WebAuthUxState.FinishTokenCollection)
            return app.t("Touche à nouveau la clé de sécurité.")
        return app.t("%1 demande une clé de sécurité : branche-la et touche-la. Les passkeys d'un téléphone ou d'un gestionnaire de mots de passe ne marchent pas dans Vigie : annule pour choisir une autre méthode.").arg(host)
    }

    // Fin de la demande (réponse à la page, ou Qt a terminé) : la fenêtre se ferme sans rien annuler.
    function finish() {
        ended = true
        close()
    }
    onStepChanged: {
        if (step === WebEngineWebAuthUxRequest.WebAuthUxState.Completed
            || step === WebEngineWebAuthUxRequest.WebAuthUxState.Cancelled)
            finish()
    }
    onClosing: {
        // Annule les demandes de la page et de ses cadres : elles échouent (AbortError), et le site
        // propose une autre méthode.
        if (!ended)
            web.runJavaScript("postMessage('vigie-webauthn-cancel', '*')")
        web.webAuthWindow = null
        destroy()
    }

    title: app.t("Clé de sécurité")
    flags: Qt.Dialog
    width: 440
    height: column.implicitHeight + 32
    visible: true

    Shortcut {
        sequence: "Escape"
        onActivated: win.close()
    }
    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        Label {
            text: win.message
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Repeater {
            model: win.selecting ? win.request.userNames : []
            Button {
                required property string modelData
                text: modelData
                Layout.fillWidth: true
                onClicked: win.request.setSelectedAccount(modelData)
            }
        }
        TextField {
            id: pin
            visible: win.pinNeeded
            echoMode: TextInput.Password
            Layout.fillWidth: true
            onVisibleChanged: if (visible) forceActiveFocus()
            onAccepted: win.request.setPin(text)
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Button {
                visible: win.pinNeeded
                text: win.app.t("Valider")
                onClicked: win.request.setPin(pin.text)
            }
            Button {
                text: win.failed ? win.app.t("Fermer") : win.app.t("Annuler")
                onClicked: win.close()
            }
        }
    }
}
