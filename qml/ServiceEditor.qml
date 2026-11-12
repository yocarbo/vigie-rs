// Ajout ou modification d'un service.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Vigie

Page {
    id: editor
    required property var app
    property var service: ({})
    property bool isNew: true
    readonly property bool navBarDefault: app.settings.nav_bar === "always"
    signal done
    signal back

    function t(text) {
        return app.t(text)
    }

    readonly property string error: {
        if (!name.text.trim())
            return t("Donne un nom au service.")
        if (!/^https?:\/\/\S+$/.test(url.text.trim()))
            return t("L'adresse doit commencer par https:// (ou http://).")
        if (url.text.includes("{"))
            return t("Remplace la partie {…} de l'adresse, par exemple par le nom de ton espace.")
        if (session.text && !/^[A-Za-z0-9_-]+$/.test(session.text))
            return t("Nom de session : lettres, chiffres, - et _ seulement.")
        return ""
    }

    function save() {
        const svc = Object.assign({}, service)
        svc.name = name.text.trim()
        svc.url = url.text.trim()
        const set = (key, value) => {
            if (value === undefined || value === null || value === false || value === "")
                delete svc[key]
            else
                svc[key] = value
        }
        set("disabled", !enabledSwitch.checked)
        set("mute_notifications", !notifications.checked)
        set("mute_sound", !sound.checked)
        set("exclude_from_total", !total.checked)
        set("hibernate", hibernate.checked)
        set("freeze_background", freezeBackground.checked)
        set("microphone", ["", "allow", "deny"][microphone.currentIndex])
        set("camera", ["", "allow", "deny"][camera.currentIndex])
        delete svc.media
        // Gardé seulement s'il diffère du réglage général, qui reste sinon la référence.
        if (navBar.checked === navBarDefault)
            delete svc.nav_bar
        else
            svc.nav_bar = navBar.checked
        set("new_windows", ["", "browser", "internal"][newWindows.currentIndex])
        set("session", session.text.trim())
        set("user_agent", userAgent.text.trim())
        set("reload_shortcut", reloadShortcut.text.trim())
        if (darkMode.currentIndex === 0)
            delete svc.dark_mode
        else
            svc.dark_mode = darkMode.currentIndex === 1
        if (isNew)
            app.addService(svc)
        else
            app.updateService(svc)
        done()
    }

    // Un onglet : réglages sur deux colonnes, défilant si besoin.
    component Tab: ScrollView {
        default property alias content: grid.data
        contentWidth: availableWidth
        // Marges haute et basse comprises, sinon le bas du dernier réglage est coupé.
        contentHeight: grid.implicitHeight + 24
        GridLayout {
            id: grid
            width: parent.width - 32
            x: 16
            y: 12
            columns: 2
            columnSpacing: 16
            rowSpacing: 10
        }
    }
    component Hint: Label {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        font.pixelSize: 12
    }

    header: ColumnLayout {
        spacing: 0
        ToolBar {
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                ToolButton {
                    text: "←"
                    font.pixelSize: 18
                    onClicked: editor.back()
                }
                Label {
                    text: editor.isNew ? editor.t("Ajouter un service") : editor.t("Modifier %1").arg(editor.service.name)
                    font.bold: true
                    Layout.fillWidth: true
                }
            }
        }
        TabBar {
            id: tabs
            Layout.fillWidth: true
            TabButton {
                text: editor.t("Général")
            }
            TabButton {
                text: editor.t("Notifications")
            }
            TabButton {
                text: editor.t("Apparence")
            }
            TabButton {
                text: editor.t("Micro et caméra")
            }
            TabButton {
                text: editor.t("Ressources")
            }
            TabButton {
                text: editor.t("Avancé")
            }
        }
    }

    // Tous les onglets restent chargés : save() lit chaque champ, même ceux d'un onglet caché.
    StackLayout {
        anchors.fill: parent
        currentIndex: tabs.currentIndex

        Tab {
            Label {
                text: editor.t("Nom")
            }
            TextField {
                id: name
                Layout.fillWidth: true
                text: editor.service.name || ""
            }
            Label {
                text: editor.t("Adresse")
            }
            TextField {
                id: url
                Layout.fillWidth: true
                text: editor.service.url || "https://"
            }
            Label {
                text: editor.t("Recipe")
            }
            Label {
                Layout.fillWidth: true
                text: editor.service.recipe ? String(editor.service.recipe).split("/").pop()
                    : editor.t("aucune (site personnalisé, sans badge)")
                opacity: 0.75
            }
            Label {
                text: editor.t("Activé")
            }
            Switch {
                id: enabledSwitch
                checked: !editor.service.disabled
            }
            Hint {
                text: editor.t("Désactivé : le service reste dans la liste, mais n'est pas chargé.")
            }
            Label {
                text: editor.t("Session partagée")
            }
            TextField {
                id: session
                Layout.fillWidth: true
                text: editor.service.session || ""
                placeholderText: editor.t("aucune : session isolée")
            }
            Hint {
                text: editor.t("Même nom sur plusieurs services (par exemple « google » pour Gmail, Agenda et Chat) : une seule connexion.")
            }
        }

        Tab {
            Label {
                text: editor.t("Notifications")
            }
            Switch {
                id: notifications
                checked: !editor.service.mute_notifications
            }
            Label {
                text: editor.t("Son")
            }
            Switch {
                id: sound
                checked: !editor.service.mute_sound
            }
            Label {
                text: editor.t("Compter dans le total")
            }
            Switch {
                id: total
                checked: !editor.service.exclude_from_total
            }
            Hint {
                text: editor.t("Décoché : le badge reste sur l'icône, mais hors du tray, du titre et de D-Bus.")
            }
        }

        Tab {
            Label {
                text: editor.t("Barre de navigation")
            }
            Switch {
                id: navBar
                checked: typeof editor.service.nav_bar === "boolean" ? editor.service.nav_bar : editor.navBarDefault
            }
            Hint {
                text: editor.t("Adresse de la page, précédent, suivant et accueil, au-dessus du service. Par défaut : selon Paramètres → Apparence.")
            }
            Label {
                text: editor.t("Mode sombre")
            }
            ComboBox {
                id: darkMode
                Layout.fillWidth: true
                model: [editor.t("Automatique"), editor.t("Toujours (en thème sombre)"), editor.t("Jamais")]
                currentIndex: editor.service.dark_mode === undefined || editor.service.dark_mode === null ? 0
                    : editor.service.dark_mode ? 1 : 2
            }
        }

        // Réponses retenues aux questions de Vigie, une par périphérique ; « Demander » l'oublie.
        Tab {
            Label {
                text: editor.t("Micro")
            }
            ComboBox {
                id: microphone
                Layout.fillWidth: true
                model: [editor.t("Demander"), editor.t("Autoriser"), editor.t("Refuser")]
                currentIndex: Math.max(0, ["", "allow", "deny"].indexOf(editor.service.microphone || editor.service.media || ""))
            }
            Label {
                text: editor.t("Caméra")
            }
            ComboBox {
                id: camera
                Layout.fillWidth: true
                model: [editor.t("Demander"), editor.t("Autoriser"), editor.t("Refuser")]
                currentIndex: Math.max(0, ["", "allow", "deny"].indexOf(editor.service.camera || editor.service.media || ""))
            }
            Hint {
                text: editor.t("Demander : Vigie pose la question la prochaine fois que le service veut s'en servir, et retient ta réponse.")
            }
        }

        Tab {
            Label {
                text: editor.t("Veille prolongée")
            }
            Switch {
                id: hibernate
                checked: !!editor.service.hibernate
            }
            Hint {
                text: editor.t("Libère la mémoire : le service est déchargé quelques minutes après l'avoir quitté (délai dans Paramètres → Général), et se recharge quand tu y reviens. Entre-temps, plus de messages ni de notifications.")
            }
            Label {
                text: editor.t("Figer en arrière-plan")
            }
            Switch {
                id: freezeBackground
                checked: !!editor.service.freeze_background
            }
            Hint {
                text: editor.t("Libère le processeur : le service est figé dès que tu en affiches un autre (plus de calcul ni de vidéo), et repart aussitôt, au même endroit, quand tu y reviens. Entre-temps, plus de messages ni de notifications : pour des caméras ou un tableau de bord, pas pour une messagerie.")
            }
        }

        Tab {
            Label {
                text: editor.t("Nouvelles fenêtres")
            }
            ComboBox {
                id: newWindows
                Layout.fillWidth: true
                model: [editor.t("Automatique"), editor.t("Navigateur par défaut"), editor.t("Fenêtre de l'app")]
                currentIndex: Math.max(0, ["auto", "browser", "internal"].indexOf(editor.service.new_windows || "auto"))
            }
            Label {
                text: editor.t("User-agent")
            }
            TextField {
                id: userAgent
                Layout.fillWidth: true
                text: editor.service.user_agent || ""
                placeholderText: editor.t("par défaut : celui des paramètres")
            }
            Label {
                text: editor.t("Raccourci pour recharger")
            }
            TextField {
                id: reloadShortcut
                Layout.fillWidth: true
                text: editor.service.reload_shortcut || ""
                placeholderText: editor.t("par défaut : celui des paramètres")
            }
        }
    }

    footer: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            Button {
                visible: !editor.isNew
                text: editor.t("Supprimer")
                onClicked: confirmDelete.open()
            }
            Label {
                Layout.fillWidth: true
                text: editor.error
                color: "#c01c28"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignRight
            }
            Button {
                text: editor.t("Annuler")
                onClicked: editor.back()
            }
            Button {
                text: editor.isNew ? editor.t("Ajouter") : editor.t("Enregistrer")
                highlighted: true
                enabled: !editor.error
                onClicked: editor.save()
            }
        }
    }

    Dialog {
        id: confirmDelete
        anchors.centerIn: parent
        modal: true
        title: editor.t("Supprimer %1 ?").arg(editor.service.name)
        Label {
            text: editor.t("Le service disparaît de Vigie ; sa connexion reste sur le disque.")
            wrapMode: Text.WordWrap
            width: 320
        }
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            editor.app.deleteService(editor.service.id)
            editor.done()
        }
    }
}
