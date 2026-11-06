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
        set("nav_bar", navBar.checked)
        set("new_windows", ["", "browser", "internal"][newWindows.currentIndex])
        set("session", session.text.trim())
        set("user_agent", userAgent.text.trim())
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

    header: ToolBar {
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

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        GridLayout {
            width: parent.width - 32
            x: 16
            y: 12
            columns: 2
            columnSpacing: 16
            rowSpacing: 10

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
                ToolTip.visible: hovered
                ToolTip.text: editor.t("Désactivé : le service reste dans la liste, mais n'est pas chargé.")
            }
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
                ToolTip.visible: hovered
                ToolTip.text: editor.t("Décoché : le badge reste sur l'icône, mais hors du tray, du titre et de D-Bus.")
            }
            Label {
                text: editor.t("Veille prolongée")
            }
            Switch {
                id: hibernate
                checked: !!editor.service.hibernate
                ToolTip.visible: hovered
                ToolTip.text: editor.t("Le service est déchargé quand il n'est pas affiché depuis un moment (voir Paramètres → Général).")
            }
            Label {
                text: editor.t("Barre de navigation")
                visible: editor.app.settings.nav_bar === "custom"
            }
            Switch {
                id: navBar
                visible: editor.app.settings.nav_bar === "custom"
                checked: !!editor.service.nav_bar
            }
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
                text: editor.t("Session partagée")
            }
            TextField {
                id: session
                Layout.fillWidth: true
                text: editor.service.session || ""
                placeholderText: editor.t("aucune : session isolée")
                ToolTip.visible: hovered
                ToolTip.text: editor.t("Même nom sur plusieurs services (par exemple « google » pour Gmail, Agenda et Chat) : une seule connexion.")
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
            Label {
                text: editor.t("User-agent")
            }
            TextField {
                id: userAgent
                Layout.fillWidth: true
                text: editor.service.user_agent || ""
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
