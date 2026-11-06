// Paramètres : services, réglages (général, notifications, apparence, confidentialité, avancé),
// catalogue des recipes, édition d'un service.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Vigie

Dialog {
    id: dlg
    required property var app
    // Catalogue lu à la première ouverture.
    property var recipes: null

    modal: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(780, app.width - 40)
    height: Math.min(700, app.height - 40)
    padding: 0
    // Fermeture : bouton ✕, Échap ou clic en dehors.
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function t(text) {
        return app.t(text)
    }
    function openSettings() {
        stack.clear()
        stack.push(mainPage)
        open()
    }
    function openCatalogue() {
        openSettings()
        stack.push(cataloguePage)
    }
    function edit(svc, isNew) {
        if (!visible) {
            stack.clear()
            stack.push(mainPage)
        }
        stack.push(editorPage, { service: svc, isNew: !!isNew })
        open()
    }
    // file:///chemin → chemin local (C:/… sous Windows).
    function localPath(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\/\/([A-Za-z]:)/, "$1").replace(/^file:\/\//, ""))
    }

    // Briques des pages de réglages ; `app` est la fenêtre principale.
    component Section: GroupBox {
        default property alias content: column.data
        Layout.fillWidth: true
        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: 6
        }
    }
    component CloseButton: ToolButton {
        readonly property var app: ApplicationWindow.window
        text: "✕"
        font.pixelSize: 16
        onClicked: app.closeSettings()
        ToolTip.visible: hovered
        ToolTip.text: app ? app.t("Fermer") : ""
    }
    component Hint: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        font.pixelSize: 12
    }
    component Toggle: Switch {
        required property string key
        readonly property var app: ApplicationWindow.window
        Layout.fillWidth: true
        checked: !!app?.settings[key]
        onToggled: app.setSetting(key, checked)
    }
    component Choice: RowLayout {
        required property string key
        property alias text: choiceLabel.text
        property var values: []
        property var labels: []
        readonly property var app: ApplicationWindow.window
        Layout.fillWidth: true
        Label {
            id: choiceLabel
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        ComboBox {
            Layout.preferredWidth: 300
            model: parent.labels
            currentIndex: Math.max(0, parent.values.indexOf(parent.app?.settings[parent.key]))
            onActivated: index => parent.app.setSetting(parent.key, parent.values[index])
        }
    }
    component Number: RowLayout {
        required property string key
        property alias text: numberLabel.text
        property int from: 0
        property int to: 240
        readonly property var app: ApplicationWindow.window
        Layout.fillWidth: true
        Label {
            id: numberLabel
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        SpinBox {
            from: parent.from
            to: parent.to
            editable: true
            value: parent.app?.settings[parent.key] ?? 0
            onValueModified: parent.app.setSetting(parent.key, value)
        }
    }
    component Field: ColumnLayout {
        required property string key
        property alias text: fieldLabel.text
        property alias placeholder: field.placeholderText
        readonly property var app: ApplicationWindow.window
        Layout.fillWidth: true
        spacing: 2
        Label {
            id: fieldLabel
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        TextField {
            id: field
            Layout.fillWidth: true
            text: parent.app?.settings[parent.key] || ""
            onEditingFinished: parent.app.setSetting(parent.key, text.trim())
        }
    }
    component Tab: ScrollView {
        default property alias content: tabColumn.data
        contentWidth: availableWidth
        // Marges haute et basse comprises, sinon le bas du dernier réglage est coupé.
        contentHeight: tabColumn.implicitHeight + 24
        ColumnLayout {
            id: tabColumn
            width: parent.width - 32
            x: 16
            y: 12
            spacing: 12
        }
    }

    contentItem: StackView {
        id: stack
    }

    Component {
        id: mainPage
        Page {
            header: RowLayout {
                spacing: 0
                TabBar {
                    id: tabs
                    Layout.fillWidth: true
                    TabButton {
                        text: dlg.t("Services")
                    }
                    TabButton {
                        text: dlg.t("Général")
                    }
                    TabButton {
                        text: dlg.t("Notifications")
                    }
                    TabButton {
                        text: dlg.t("Apparence")
                    }
                    TabButton {
                        text: dlg.t("Confidentialité")
                    }
                    TabButton {
                        text: dlg.t("Avancé")
                    }
                }
                CloseButton {}
            }
            StackLayout {
                anchors.fill: parent
                currentIndex: tabs.currentIndex

                // Services
                ColumnLayout {
                    spacing: 8
                    RowLayout {
                        Layout.margins: 16
                        Layout.bottomMargin: 0
                        Label {
                            text: dlg.t("Chaque service est isolé (cookies, stockage), sauf s'il partage une session nommée.")
                            wrapMode: Text.WordWrap
                            opacity: 0.75
                            Layout.fillWidth: true
                        }
                        Button {
                            text: dlg.t("Ajouter…")
                            onClicked: stack.push(cataloguePage)
                        }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 16
                        Layout.topMargin: 0
                        clip: true
                        model: dlg.app.serviceModel
                        delegate: ItemDelegate {
                            required property string json
                            required property string favicon
                            readonly property var svc: JSON.parse(json)
                            width: ListView.view.width
                            onClicked: dlg.edit(svc, false)
                            contentItem: RowLayout {
                                spacing: 12
                                opacity: svc.disabled ? 0.5 : 1
                                // Comme dans la barre latérale : logo, sinon favicon, sinon initiales.
                                ServiceLogo {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    name: svc.name
                                    source: dlg.app.info(svc).icon || favicon
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    Label {
                                        text: svc.disabled ? dlg.t("%1 (désactivé)").arg(svc.name) : svc.name
                                        font.bold: true
                                        textFormat: Text.PlainText
                                    }
                                    Label {
                                        text: svc.url
                                        opacity: 0.7
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        maximumLineCount: 1
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: dlg.t("Aucun service pour l'instant")
                            opacity: 0.7
                        }
                    }
                }

                // Général
                Tab {
                    Section {
                        title: dlg.t("Démarrage et fenêtre")
                        Switch {
                            Layout.fillWidth: true
                            text: dlg.t("Lancer Vigie à l'ouverture de session")
                            checked: Backend.autostartEnabled()
                            onToggled: {
                                const error = Backend.setAutostart(checked)
                                if (error) {
                                    checked = !checked
                                    dlg.app.toastMessage(error)
                                }
                            }
                        }
                        Toggle {
                            key: "start_minimized"
                            text: dlg.t("Démarrer minimisé (dans la zone de notification)")
                        }
                        Toggle {
                            key: "keep_in_background"
                            text: dlg.t("Garder Vigie ouvert en arrière-plan quand on ferme la fenêtre")
                        }
                        Switch {
                            Layout.fillWidth: true
                            text: dlg.t("Confirmer avant de quitter Vigie")
                            checked: !dlg.app.settings.quit_without_asking
                            onToggled: dlg.app.setSetting("quit_without_asking", !checked)
                        }
                        Toggle {
                            key: "show_tray"
                            text: dlg.t("Toujours afficher l'icône de Vigie dans la zone de notification")
                        }
                    }
                    Section {
                        title: dlg.t("Langue")
                        Choice {
                            key: "language"
                            text: dlg.t("Langue de l'interface")
                            values: ["system", "fr", "en"]
                            labels: [dlg.t("Langue du système"), "Français", "English"]
                        }
                    }
                    Section {
                        title: dlg.t("Veille et reprise")
                        Toggle {
                            key: "reload_after_resume"
                            text: dlg.t("Recharger les services après la reprise du système")
                        }
                        Number {
                            key: "idle_minutes"
                            from: 1
                            text: dlg.t("Délai pour considérer le système comme inactif ou suspendu (minutes)")
                        }
                        Choice {
                            key: "hibernation_minutes"
                            text: dlg.t("Veille prolongée des services")
                            values: [0, 1, 5, 10, 30]
                            labels: [dlg.t("Désactivée"), dlg.t("Très rapide (1 min)"), dlg.t("Normale (5 min)"),
                                dlg.t("Lente (10 min)"), dlg.t("Très lente (30 min)")]
                        }
                        Toggle {
                            key: "hibernate_on_start"
                            text: dlg.t("Garder les services en veille prolongée au démarrage")
                        }
                        Hint {
                            text: dlg.t("Seuls les services où la veille prolongée est activée (clic droit, ou modification du service) sont déchargés quand ils ne sont pas affichés. En veille, un service ne reçoit plus de messages ni de notifications.")
                        }
                    }
                    Section {
                        title: dlg.t("Sauvegarde")
                        Hint {
                            text: dlg.t("Services et réglages dans un fichier JSON. Les connexions ne sont pas incluses : il faudra se reconnecter.")
                        }
                        RowLayout {
                            Button {
                                text: dlg.t("Exporter la configuration…")
                                onClicked: exportDialog.open()
                            }
                            Button {
                                text: dlg.t("Importer une configuration…")
                                onClicked: importDialog.open()
                            }
                        }
                    }
                    Section {
                        id: updates
                        readonly property var info: JSON.parse(Backend.versionInfo())
                        title: dlg.t("Mises à jour")
                        Hint {
                            text: updates.info.channel === "release"
                                ? dlg.t("Version %1, installée depuis une release GitHub.").arg(updates.info.version)
                                    + (updates.info.canInstall ? ""
                                        : " " + dlg.t("Vigie ne peut pas remplacer ses fichiers : il signale les nouvelles versions sans les installer."))
                                : updates.info.channel === "source"
                                ? dlg.t("Version %1, compilée depuis les sources (commit %2) : ./vigie-rs update installe les nouveautés de main.").arg(updates.info.version).arg(updates.info.commit)
                                : dlg.t("Version %1, compilée à la main.").arg(updates.info.version)
                        }
                        Toggle {
                            key: "update_check"
                            text: dlg.t("Rechercher les mises à jour chaque semaine (une requête à GitHub)")
                        }
                        RowLayout {
                            Button {
                                text: dlg.t("Rechercher maintenant")
                                onClicked: dlg.app.checkUpdates(true)
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: dlg.app.updateStatus
                            }
                        }
                    }
                }

                // Notifications
                Tab {
                    Section {
                        title: dlg.t("Notifications")
                        Toggle {
                            key: "dnd"
                            text: dlg.t("Ne pas déranger (aucune notification ni son)")
                        }
                        Toggle {
                            key: "hide_notification_content"
                            text: dlg.t("Ne pas afficher le contenu des notifications")
                        }
                        Toggle {
                            key: "badges_when_muted"
                            text: dlg.t("Afficher les badges des services dont les notifications sont coupées")
                        }
                    }
                    Section {
                        title: dlg.t("Codes à deux facteurs")
                        Toggle {
                            key: "auto_copy_2fa"
                            text: dlg.t("Copier dans le presse-papiers les codes reçus en notification (SMS…)")
                        }
                        Field {
                            key: "codes_keywords"
                            text: dlg.t("Mots-clés qui signalent un code, séparés par des virgules (majuscules indifférentes)")
                            placeholder: "token, code, sms, verify"
                        }
                    }
                }

                // Apparence
                Tab {
                    Section {
                        title: dlg.t("Apparence")
                        Choice {
                            key: "theme"
                            text: dlg.t("Thème")
                            values: ["system", "light", "dark"]
                            labels: [dlg.t("Système"), dlg.t("Clair"), dlg.t("Sombre")]
                        }
                        Hint {
                            text: dlg.t("En sombre, chaque service prend le thème sombre de sa recipe, ou le mode sombre automatique si tu l'actives sur le service.")
                        }
                        Choice {
                            key: "icon_size"
                            text: dlg.t("Taille des icônes des services")
                            values: ["small", "normal", "large"]
                            labels: [dlg.t("Petites"), dlg.t("Normales"), dlg.t("Grandes")]
                        }
                        Toggle {
                            key: "show_names"
                            text: dlg.t("Afficher le nom du service sous l'icône")
                        }
                        Toggle {
                            key: "show_disabled"
                            text: dlg.t("Afficher les services désactivés dans la barre latérale")
                        }
                        Choice {
                            key: "nav_bar"
                            text: dlg.t("Barre de navigation")
                            values: ["never", "always", "custom"]
                            labels: [dlg.t("Jamais"), dlg.t("Toujours"), dlg.t("Selon le service")]
                        }
                    }
                }

                // Confidentialité
                Tab {
                    Section {
                        title: dlg.t("Verrouillage")
                        Switch {
                            Layout.fillWidth: true
                            text: dlg.t("Activer le verrouillage par mot de passe")
                            checked: !!dlg.app.settings.lock_enabled
                            onToggled: {
                                if (checked && !dlg.app.settings.lock_hash) {
                                    checked = false
                                    passwordDialog.open()
                                } else {
                                    dlg.app.setSetting("lock_enabled", checked)
                                }
                            }
                        }
                        Number {
                            key: "lock_minutes"
                            text: dlg.t("Verrouiller après ce nombre de minutes hors de la fenêtre (0 : au démarrage et à la demande seulement)")
                        }
                        RowLayout {
                            Button {
                                text: dlg.t("Changer le mot de passe…")
                                onClicked: passwordDialog.open()
                            }
                            Button {
                                text: dlg.t("Verrouiller maintenant")
                                enabled: !!dlg.app.settings.lock_enabled && !!dlg.app.settings.lock_hash
                                onClicked: {
                                    dlg.close()
                                    dlg.app.lock()
                                }
                            }
                        }
                        Hint {
                            text: dlg.t("Le verrouillage cache Vigie et le contenu des notifications. Les services continuent de tourner, et leurs données restent sur le disque, protégées par le chiffrement du disque.")
                        }
                    }
                    Section {
                        title: dlg.t("WebRTC (appels)")
                        Choice {
                            key: "webrtc_ip_policy"
                            text: dlg.t("Adresses IP exposées aux sites")
                            values: ["default", "default_public_and_private_interfaces", "default_public_interface_only", "disable_non_proxied_udp"]
                            labels: [dlg.t("IP publiques et locales (par défaut)"), dlg.t("IP publique et IP locale de la route par défaut"),
                                dlg.t("IP publique seulement"), dlg.t("Ni IP publique, ni IP locale")]
                        }
                        Hint {
                            text: dlg.t("Appliqué au prochain lancement de Vigie. Sans IP exposée, certains appels peuvent échouer.")
                        }
                    }
                }

                // Avancé
                Tab {
                    Section {
                        title: dlg.t("Téléchargements")
                        RowLayout {
                            Layout.fillWidth: true
                            enabled: !dlg.app.settings.download_ask
                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                text: dlg.app.settings.download_dir
                                    || dlg.t("%1 (dossier par défaut)").arg(Backend.downloadsDir())
                            }
                            Button {
                                text: dlg.t("Choisir un dossier…")
                                onClicked: folderDialog.open()
                            }
                            Button {
                                text: dlg.t("Dossier par défaut")
                                enabled: !!dlg.app.settings.download_dir
                                onClicked: dlg.app.setSetting("download_dir", "")
                            }
                        }
                        Toggle {
                            key: "download_ask"
                            text: dlg.t("Demander où enregistrer à chaque téléchargement")
                        }
                    }
                    Section {
                        title: dlg.t("Navigateur")
                        Field {
                            key: "user_agent"
                            text: dlg.t("User-agent par défaut (chaque service peut avoir le sien)")
                            placeholder: dlg.app.defaultUserAgent
                        }
                        Toggle {
                            key: "update_user_agent"
                            text: dlg.t("Tenir à jour la version de Chrome du user-agent (une requête par semaine à Google)")
                        }
                        Hint {
                            text: dlg.t("User-agent utilisé : %1").arg(dlg.app.settings.user_agent || dlg.app.defaultUserAgent)
                        }
                        Toggle {
                            key: "gpu"
                            text: dlg.t("Accélération GPU (appliquée au prochain lancement)")
                        }
                    }
                    Section {
                        title: dlg.t("Correcteur et traduction")
                        Toggle {
                            key: "spellcheck"
                            text: dlg.t("Vérification orthographique")
                        }
                        Choice {
                            key: "spellcheck_language"
                            text: dlg.t("Langue de la vérification")
                            values: ["auto", "fr-FR", "en-US"]
                            labels: [dlg.t("Français et anglais"), dlg.t("Français"), dlg.t("Anglais")]
                        }
                        Toggle {
                            key: "translator"
                            text: dlg.t("Traducteur : « Traduire » dans le clic droit sur une sélection")
                        }
                        Choice {
                            key: "translator_engine"
                            text: dlg.t("Service de traduction")
                            values: ["google", "deepl"]
                            labels: ["Google Traduction", "DeepL"]
                        }
                        Choice {
                            key: "translator_language"
                            text: dlg.t("Traduire vers")
                            values: ["", "fr", "en", "de", "es", "it"]
                            labels: [dlg.t("La langue de l'interface"), "Français", "English", "Deutsch", "Español", "Italiano"]
                        }
                        Hint {
                            text: dlg.t("La traduction ouvre le texte sélectionné dans le navigateur, sur le service choisi.")
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: exportDialog
        title: dlg.t("Exporter la configuration")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [dlg.t("Configuration (*.json)")]
        onAccepted: dlg.app.exportConfig(dlg.localPath(selectedFile))
    }
    FileDialog {
        id: importDialog
        title: dlg.t("Importer une configuration (remplace tous les services)")
        fileMode: FileDialog.OpenFile
        nameFilters: [dlg.t("Configuration (*.json)")]
        onAccepted: dlg.app.importConfig(dlg.localPath(selectedFile))
    }
    FolderDialog {
        id: folderDialog
        title: dlg.t("Dossier des téléchargements")
        onAccepted: dlg.app.setSetting("download_dir", dlg.localPath(selectedFolder))
    }

    // Mot de passe de verrouillage : seule son empreinte (Argon2) est enregistrée.
    Dialog {
        id: passwordDialog
        anchors.centerIn: parent
        modal: true
        title: dlg.t("Mot de passe de verrouillage")
        onOpened: {
            first.text = ""
            second.text = ""
            first.forceActiveFocus()
        }
        ColumnLayout {
            width: 340
            TextField {
                id: first
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: dlg.t("Mot de passe")
            }
            TextField {
                id: second
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: dlg.t("Le même, pour confirmer")
            }
            Label {
                Layout.fillWidth: true
                color: "#c01c28"
                wrapMode: Text.WordWrap
                text: first.text && second.text && first.text !== second.text ? dlg.t("Les deux mots de passe diffèrent.") : ""
            }
        }
        footer: DialogButtonBox {
            Button {
                text: dlg.t("Annuler")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            Button {
                text: dlg.t("Enregistrer")
                enabled: first.text.length > 0 && first.text === second.text
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }
        onAccepted: {
            dlg.app.setSetting("lock_hash", Backend.hashPassword(first.text))
            dlg.app.setSetting("lock_enabled", true)
        }
    }

    Component {
        id: cataloguePage
        Page {
            id: catalogue
            readonly property var shown: {
                if (!dlg.recipes)
                    dlg.recipes = JSON.parse(Backend.catalogue())
                const q = search.text.trim().toLowerCase()
                return q ? dlg.recipes.filter(r => r.name.toLowerCase().includes(q)) : dlg.recipes
            }
            header: ToolBar {
                RowLayout {
                    anchors.fill: parent
                    ToolButton {
                        text: "←"
                        font.pixelSize: 18
                        onClicked: stack.pop()
                    }
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        placeholderText: dlg.t("Rechercher parmi %1 services").arg((dlg.recipes || []).length)
                        focus: true
                    }
                    CloseButton {}
                }
            }
            ListView {
                anchors.fill: parent
                clip: true
                model: catalogue.shown
                header: ItemDelegate {
                    width: ListView.view.width
                    onClicked: dlg.edit({ name: "", url: "https://" }, true)
                    contentItem: ColumnLayout {
                        spacing: 0
                        Label {
                            text: dlg.t("Site web personnalisé")
                            font.bold: true
                        }
                        Label {
                            text: dlg.t("N'importe quelle URL, sans recipe (pas de badge)")
                            opacity: 0.7
                        }
                    }
                }
                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    onClicked: dlg.edit({ name: modelData.name, url: modelData.url, recipe: modelData.dir }, true)
                    contentItem: RowLayout {
                        spacing: 12
                        Image {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(64, 64)
                            asynchronous: true
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Label {
                                text: modelData.name
                                font.bold: true
                                textFormat: Text.PlainText
                            }
                            Label {
                                text: modelData.url
                                opacity: 0.7
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: editorPage
        ServiceEditor {
            app: dlg.app
            onDone: dlg.close()
            onBack: stack.depth > 1 ? stack.pop() : dlg.close()
        }
    }
}
