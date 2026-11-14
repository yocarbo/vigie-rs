// Vue web d'un service : son profil (session), sa recipe dans un monde isolé, ses fenêtres,
// sa barre de navigation, sa mise en veille prolongée et son menu contextuel.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebChannel
import QtWebEngine
import Vigie

Item {
    id: view
    required property var app
    required property string sid
    required property string json
    readonly property var svc: JSON.parse(json)
    readonly property var info: app.info(svc)
    // Mode sombre de la page : thème de la recipe s'il existe, sinon mode sombre automatique de Chromium.
    readonly property bool darkFor: app.dark && (svc.dark_mode ?? info.recipeDark)
    // Celui du service s'il en a un, sinon le réglage général (« custom », ancienne valeur : jamais).
    readonly property bool showNav: typeof svc.nav_bar === "boolean" ? svc.nav_bar : app.settings.nav_bar === "always"
    property bool recipeForcesDark: false
    property var detachedWindow: null
    // Veille prolongée : page chargée seulement à la première ouverture (veille au démarrage),
    // déchargée après N minutes sans être affichée.
    property string pendingUrl: ""
    property double lastShown: Date.now()

    anchors.fill: parent
    visible: sid === app.current

    function t(text) {
        return app.t(text)
    }
    function reload() {
        web.reload()
    }
    function wake() {
        lastShown = Date.now()
        if (web.lifecycleState !== WebEngineView.LifecycleState.Active)
            web.lifecycleState = WebEngineView.LifecycleState.Active
        if (pendingUrl) {
            web.url = pendingUrl
            pendingUrl = ""
        }
    }
    onVisibleChanged: {
        if (visible)
            wake()
        else
            lastShown = Date.now()
    }
    // Figer en arrière-plan (option du service) : la page est gelée, sans calcul, vidéo ni message (ni
    // notification), et reprend aussitôt affichée, sans recharger. Qt ne gèle qu'une vue cachée ;
    // gelée seulement une fois chargée, pour garder son badge.
    readonly property bool paused: !visible && !detachedWindow && !!svc.freeze_background
    onPausedChanged: applyPause()
    function applyPause() {
        if (paused && web.lifecycleState === WebEngineView.LifecycleState.Active && !web.loading && !pendingUrl)
            web.lifecycleState = WebEngineView.LifecycleState.Frozen
        else if (!paused && web.lifecycleState === WebEngineView.LifecycleState.Frozen)
            web.lifecycleState = WebEngineView.LifecycleState.Active
    }
    // Micro et caméra retenus pour le service, chacun le sien (« allow », « deny », ou rien) : la page les
    // voit aussitôt (voir mediaScript), sans attendre un rechargement.
    readonly property string mediaJson: JSON.stringify({
        microphone: svc.microphone || svc.media || "",
        camera: svc.camera || svc.media || "",
    })
    onMediaJsonChanged: {
        installScripts()
        web.runJavaScript(`window.__vigieSetMedia && window.__vigieSetMedia(${mediaJson})`)
    }
    // Chargé caché (au démarrage, ou rechargé) : gelé une fois que sa recipe a lu son badge.
    Timer {
        id: pauseAfterLoad
        interval: 10000
        onTriggered: view.applyPause()
    }
    function maybeHibernate(now, minutes) {
        if (!visible && !detachedWindow && svc.hibernate && web.lifecycleState !== WebEngineView.LifecycleState.Discarded
                && now - lastShown > minutes * 60000) {
            console.log(`[${svc.name}] veille prolongée`)
            web.lifecycleState = WebEngineView.LifecycleState.Discarded
        }
    }
    // Connexion à Google faite ailleurs dans la session (`done`) : quitte la page de connexion.
    function afterSignIn(done) {
        if (web !== done && app.isSignIn(web.url))
            web.url = svc.url
    }
    function reloadIfAwake() {
        if (web.lifecycleState === WebEngineView.LifecycleState.Active && !pendingUrl)
            web.reload()
    }

    // Une fenêtre à part, sans recharger la page ; la fermer remet la page ici.
    function detach() {
        if (detachedWindow) {
            detachedWindow.raise()
            return
        }
        wake()
        detachedWindow = detachedComponent.createObject(app, { title: svc.name })
        web.parent = detachedWindow.contentItem
        detachedWindow.closing.connect(() => {
            web.parent = page
            detachedWindow.destroy()
            detachedWindow = null
        })
    }
    Component {
        id: detachedComponent
        ApplicationWindow {
            width: 1100
            height: 760
            visible: true
        }
    }

    function script(name, props) {
        const s = WebEngine.script()
        s.name = name
        for (const k in props)
            s[k] = props[k]
        return s
    }
    // Micro et caméra : Qt ne les accorde qu'à la page qui les demande (la fenêtre d'appel de Slack), pas
    // au site comme Chrome. Or Slack, dans sa page principale, lit l'état (navigator.permissions) et la
    // liste des périphériques, que Chromium rend sans identifiants ni noms à une page qui ne les a pas
    // eus : Slack n'y trouvait aucun micro. Avec les réponses retenues par Vigie :
    // - l'état rendu est « accordé » ou « refusé », tenu à jour (Slack s'abonne à son « change ») ;
    // - un périphérique autorisé est obtenu un instant par la page affichée (coupé aussitôt, sans
    //   question puisque la réponse est retenue), et la liste devient complète, comme dans Chrome.
    readonly property string mediaScript: `(() => {
        window.__vigieMedia = ${mediaJson}
        const p = navigator.permissions
        const md = navigator.mediaDevices
        if (!p || !md) return
        const query = p.query.bind(p)
        const enumerate = md.enumerateDevices.bind(md)
        const gum = md.getUserMedia.bind(md)
        // Un état par nom, réutilisé (Slack interroge en boucle).
        const statuses = {}
        const stateOf = (name, native) => {
            const m = window.__vigieMedia[name]
            return m === 'allow' ? 'granted' : m === 'deny' ? 'denied' : native
        }
        const update = s => {
            const state = stateOf(s.name, s.native)
            if (state === s.state) return
            s.state = state
            s.dispatchEvent(new Event('change'))
            if (typeof s.onchange === 'function') s.onchange(new Event('change'))
        }
        p.query = d => {
            if (!d || (d.name !== 'microphone' && d.name !== 'camera')) return query(d)
            return query(d).then(n => n.state, () => 'prompt').then(native => {
                let s = statuses[d.name]
                if (!s) {
                    s = statuses[d.name] = new EventTarget()
                    s.name = d.name
                    s.onchange = null
                    s.state = stateOf(d.name, native)
                }
                s.native = native
                update(s)
                return s
            })
        }
        // Périphériques autorisés que la page n'a pas encore eus : obtenus puis coupés aussitôt.
        let warmed = {}
        const warm = async list => {
            const need = {}
            const missing = kind => list.some(d => d.kind === kind && !d.deviceId)
            if (window.__vigieMedia.microphone === 'allow' && !warmed.audio && missing('audioinput')) need.audio = true
            if (window.__vigieMedia.camera === 'allow' && !warmed.video && missing('videoinput')) need.video = true
            if (!(need.audio || need.video) || document.visibilityState !== 'visible') return false
            warmed = { ...warmed, ...need }
            try {
                const s = await gum(need)
                s.getTracks().forEach(t => t.stop())
                return true
            } catch (e) {
                return false
            }
        }
        md.enumerateDevices = async () => {
            const list = await enumerate()
            return await warm(list) ? enumerate() : list
        }
        // Affichée plus tard, ou réponse donnée entre-temps : la page relit la liste (devicechange).
        const refresh = async () => {
            if (await warm(await enumerate())) md.dispatchEvent(new Event('devicechange'))
        }
        document.addEventListener('visibilitychange', refresh)
        window.__vigieSetMedia = m => {
            window.__vigieMedia = m
            Object.values(statuses).forEach(update)
            refresh()
        }
    })()`
    // Monde de la page : window.vigie, micro et caméra. Monde isolé : QWebChannel puis la recipe
    // (absente si aucune).
    function installScripts() {
        web.userScripts.clear()
        web.userScripts.insert(script("vigie-page", {
            sourceCode: Backend.mainWorldScript(),
            injectionPoint: WebEngineScript.DocumentCreation,
            worldId: WebEngineScript.MainWorld,
            runsOnSubFrames: false,
        }))
        web.userScripts.insert(script("vigie-media", {
            sourceCode: mediaScript,
            injectionPoint: WebEngineScript.DocumentCreation,
            worldId: WebEngineScript.MainWorld,
            runsOnSubFrames: true,
        }))
        const code = Backend.recipeScript(json, darkFor)
        if (!code)
            return
        web.userScripts.insert(script("qwebchannel", {
            sourceUrl: "qrc:/qtwebchannel/qwebchannel.js",
            injectionPoint: WebEngineScript.DocumentCreation,
            worldId: WebEngineScript.ApplicationWorld,
            runsOnSubFrames: false,
        }))
        web.userScripts.insert(script("vigie-recipe", {
            sourceCode: code,
            injectionPoint: WebEngineScript.DocumentReady,
            worldId: WebEngineScript.ApplicationWorld,
            runsOnSubFrames: false,
        }))
    }
    onDarkForChanged: {
        installScripts()
        web.runJavaScript(`typeof __vigieSetDark === "function" && __vigieSetDark(${darkFor})`,
            WebEngineScript.ApplicationWorld)
    }

    // Messages de la recipe (monde isolé) : badge, scripts du monde de la page, liens.
    function handle(m) {
        switch (m.type) {
        case "badge":
            app.setBadge(sid, m.direct, m.indirect)
            break
        case "js":
            web.runJavaScript(m.code)
            break
        case "open":
            app.openExternal(m.url)
            break
        case "clear":
            web.profile.clearHttpCache()
            break
        case "avatar":
            app.setAvatar(sid, m.url)
            break
        case "forceDark":
            recipeForcesDark = m.on
            break
        }
    }
    WebChannel {
        id: channel
        registeredObjects: [bridge]
    }
    QtObject {
        id: bridge
        WebChannel.id: "vigie"
        function message(json) {
            try {
                view.handle(JSON.parse(json))
            } catch (e) {
                console.log(`[${view.svc.name}] message de recipe invalide : ${e}`)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Barre de navigation (réglage global, ou par service).
        ToolBar {
            Layout.fillWidth: true
            visible: view.showNav
            RowLayout {
                anchors.fill: parent
                spacing: 2
                ToolButton {
                    text: "←"
                    enabled: web.canGoBack
                    onClicked: web.goBack()
                    ToolTip.visible: hovered
                    ToolTip.text: view.t("Précédent")
                }
                ToolButton {
                    text: "→"
                    enabled: web.canGoForward
                    onClicked: web.goForward()
                    ToolTip.visible: hovered
                    ToolTip.text: view.t("Suivant")
                }
                ToolButton {
                    text: "⌂"
                    onClicked: web.url = view.svc.url
                    ToolTip.visible: hovered
                    ToolTip.text: view.t("Accueil du service")
                }
                TextField {
                    id: address
                    Layout.fillWidth: true
                    text: String(web.url)
                    selectByMouse: true
                    onAccepted: web.url = /^[a-z]+:/.test(text) ? text : "https://" + text
                }
                ToolButton {
                    text: "↗"
                    onClicked: view.app.openExternal(String(web.url))
                    ToolTip.visible: hovered
                    ToolTip.text: view.t("Ouvrir dans le navigateur")
                }
            }
        }

        Item {
            id: page
            Layout.fillWidth: true
            Layout.fillHeight: true

            WebEngineView {
                id: web
                anchors.fill: parent
                webChannel: channel
                webChannelWorld: WebEngineScript.ApplicationWorld
                audioMuted: view.app.muted || !!view.svc.mute_sound
                settings.forceDarkMode: view.recipeForcesDark || (view.darkFor && !view.info.recipeDark)
                settings.focusOnNavigationEnabled: false
                // Boutons « Copier le lien » (navigator.clipboard.writeText) ; lire le presse-papiers
                // reste refusé (askPermission).
                settings.javascriptCanAccessClipboard: true
                // Partage d'écran (coupé par défaut dans Qt) : Vigie pose la question (askPermission).
                settings.screenCaptureEnabled: true
                onIconChanged: view.app.setFavicon(view.sid, icon)
                onPermissionRequested: permission => view.app.askPermission(view.svc, permission, web.Window.window)
                onNewWindowRequested: request => view.app.newWindow(view.svc, web.profile, request)
                property var webAuthWindow: null
                onWebAuthUxRequested: request => view.app.webAuth(web, request)
                onNavigationRequested: request => {
                    if (!request.isMainFrame)
                        return
                    // Notifications accordées d'avance, comme à la demande : Slack… n'affichent plus
                    // leur bandeau « autorisez les notifications » à chaque lancement.
                    web.profile.queryPermission(request.url, WebEnginePermission.PermissionType.Notifications).grant()
                    if (view.app.googlePage(view.svc, request.url, web))
                        request.reject()
                }
                onLoadingChanged: info => {
                    if (info.status === WebEngineLoadingInfo.LoadSucceededStatus) {
                        retry.failed = false
                        retry.tries = 0
                        view.app.googlePageLoaded(view.svc, web, info.url)
                        pauseAfterLoad.restart()
                    } else if (info.status === WebEngineLoadingInfo.LoadFailedStatus
                               && [21, 102, 104, 105, 106, 109, 118, 137].includes(Math.abs(info.errorCode))) {
                        retry.failed = true
                        if (retry.tries < 4) {
                            retry.interval = 2000 << retry.tries++
                            retry.restart()
                        }
                    }
                }
                // Réseau pas encore là (ouverture de session, sortie de veille, Wi-Fi ou VPN qui se
                // connecte) : Chromium affiche sa page d'erreur (ERR_NETWORK_CHANGED, pas d'Internet,
                // nom ou serveur introuvable…) et n'y revient pas. Vigie recharge 4 fois (2, 4, 8, 16 s :
                // le réseau qui arrive pendant le chargement), puis attend NetworkManager : quand Internet
                // revient, un seul rechargement, décalé au hasard de quelques secondes d'un service à
                // l'autre pour ne pas tout relancer d'un coup. Jamais de rechargement en boucle.
                Timer {
                    id: retry
                    property bool failed: false
                    property int tries: 0
                    onTriggered: web.reload()
                }
                Connections {
                    target: Backend
                    function onNetworkOnline() {
                        if (!retry.failed)
                            return
                        retry.tries = 0
                        retry.interval = 500 + Math.random() * 4500
                        retry.restart()
                    }
                }
                onFullScreenRequested: request => request.accept()
                onContextMenuRequested: request => {
                    request.accepted = true
                    contextMenu.show(request)
                }
                onJavaScriptConsoleMessage: (level, message, line, source) => {
                    view.app.webAuthMessage(web, message)
                    if (view.app.logConsole)
                        console.log(`[${view.svc.name}] console : ${message}`)
                }
                onRenderProcessTerminated: (status, code) => {
                    console.log(`[${view.svc.name}] processus de la page arrêté (${status}), rechargement`)
                    reloadTimer.start()
                }
                Timer {
                    id: reloadTimer
                    interval: 1000
                    onTriggered: web.reload()
                }
            }

            // Place laissée dans la fenêtre principale quand la page est dans une fenêtre à part.
            ColumnLayout {
                anchors.centerIn: parent
                visible: !!view.detachedWindow
                spacing: 12
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.t("%1 est dans une fenêtre séparée").arg(view.svc.name)
                    font.pixelSize: 18
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.t("Remettre dans la fenêtre principale")
                    onClicked: view.detachedWindow.close()
                }
            }
        }
    }

    // Menu contextuel : suggestions du correcteur, édition, liens, images, traduction, navigation.
    Menu {
        id: contextMenu
        // Copie des infos de la demande (l'objet de Qt n'est valable que pendant le signal).
        property var r: ({})
        function show(request) {
            r = {
                selectedText: request.selectedText,
                linkUrl: String(request.linkUrl),
                mediaUrl: String(request.mediaUrl),
                isImage: request.mediaType === ContextMenuRequest.MediaTypeImage,
                editable: request.isContentEditable,
                misspelled: request.misspelledWord,
                suggestions: request.spellCheckerSuggestions || [],
            }
            popup()
        }
        component Entry: MenuItem {
            height: visible ? implicitHeight : 0
        }

        Instantiator {
            model: contextMenu.r.suggestions || []
            delegate: MenuItem {
                required property string modelData
                text: modelData
                font.bold: true
                onTriggered: web.replaceMisspelledWord(modelData)
            }
            onObjectAdded: (index, object) => contextMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => contextMenu.removeItem(object)
        }
        Entry {
            visible: !!contextMenu.r.misspelled && !(contextMenu.r.suggestions || []).length
            enabled: false
            text: view.t("Aucune suggestion")
        }
        Entry {
            text: view.t("Couper")
            visible: !!contextMenu.r.editable
            onTriggered: web.triggerWebAction(WebEngineView.Cut)
        }
        Entry {
            text: view.t("Copier")
            visible: !!contextMenu.r.selectedText
            onTriggered: web.triggerWebAction(WebEngineView.Copy)
        }
        Entry {
            text: view.t("Coller")
            visible: !!contextMenu.r.editable
            onTriggered: web.triggerWebAction(WebEngineView.Paste)
        }
        Entry {
            text: view.t("Tout sélectionner")
            visible: !!contextMenu.r.editable
            onTriggered: web.triggerWebAction(WebEngineView.SelectAll)
        }
        Entry {
            text: view.t("Traduire « %1 »").arg(String(contextMenu.r.selectedText || "").slice(0, 30))
            visible: !!view.app.settings.translator && !!contextMenu.r.selectedText
            onTriggered: view.app.translate(contextMenu.r.selectedText)
        }
        Entry {
            text: view.t("Ouvrir le lien dans le navigateur")
            visible: !!contextMenu.r.linkUrl
            onTriggered: view.app.openExternal(contextMenu.r.linkUrl)
        }
        Entry {
            text: view.t("Copier l'adresse du lien")
            visible: !!contextMenu.r.linkUrl
            onTriggered: web.triggerWebAction(WebEngineView.CopyLinkToClipboard)
        }
        Entry {
            text: view.t("Copier l'image")
            visible: !!contextMenu.r.isImage
            onTriggered: web.triggerWebAction(WebEngineView.CopyImageToClipboard)
        }
        Entry {
            text: view.t("Enregistrer l'image…")
            visible: !!contextMenu.r.isImage
            onTriggered: web.triggerWebAction(WebEngineView.DownloadImageToDisk)
        }
        MenuSeparator {}
        Entry {
            text: view.t("Précédent")
            enabled: web.canGoBack
            onTriggered: web.goBack()
        }
        Entry {
            text: view.t("Suivant")
            enabled: web.canGoForward
            onTriggered: web.goForward()
        }
        Entry {
            text: view.t("Recharger")
            onTriggered: web.reload()
        }
        Entry {
            text: view.t("Inspecter")
            onTriggered: view.inspect()
        }
    }

    // Outils de développement de Chromium (éléments, console, réseau) dans une fenêtre à part.
    property var inspector: null
    function inspect() {
        if (!inspector) {
            inspector = inspectorComponent.createObject(app, { title: t("Inspecteur — %1").arg(svc.name) })
            inspector.closing.connect(() => {
                web.devToolsView = null
                inspector.destroy()
                inspector = null
            })
        }
        inspector.raise()
    }
    Component {
        id: inspectorComponent
        ApplicationWindow {
            width: 1100
            height: 700
            visible: true
            WebEngineView {
                id: tools
                anchors.fill: parent
                profile: web.profile
            }
            // Posé une fois la fenêtre créée : `inspectedView` dès la création fait planter Chromium.
            Component.onCompleted: Qt.callLater(() => web.devToolsView = tools)
        }
    }

    Component.onCompleted: {
        app.views[sid] = view
        // Posé une fois, avant la première page : le profil porte la session du service.
        web.profile = app.profileFor(svc)
        installScripts()
        if (svc.hibernate && app.settings.hibernate_on_start && !visible)
            pendingUrl = svc.url
        else
            web.url = svc.url
    }
    Component.onDestruction: {
        if (app.views[sid] === view)
            delete app.views[sid]
        if (detachedWindow)
            detachedWindow.destroy()
        if (inspector)
            inspector.destroy()
    }
}
