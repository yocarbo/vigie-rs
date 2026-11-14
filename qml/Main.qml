// Fenêtre principale : barre latérale des services, une vue web par service, tray, dialogues.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtWebEngine
import Qt.labs.platform as Platform
import Vigie

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    // Affichée au démarrage par Component.onCompleted (sauf démarrage minimisé).
    visible: false
    // Titre : non-lus et service affiché (Qt ajoute « — Vigie »).
    title: (total > 0 ? `(${total}) ` : "") + ((serviceById(current) || {}).name || "Vigie")

    // Réglages hors services ; les services sont dans `services`. Valeurs par défaut :
    readonly property var defaults: ({
        theme: "system", language: "system", quit_without_asking: false,
        start_minimized: false, keep_in_background: false, show_tray: true,
        dnd: false, hide_notification_content: false, badges_when_muted: true,
        auto_copy_2fa: false, codes_keywords: "token, code, sms, verify",
        icon_size: "normal", show_names: false, show_disabled: true,
        reload_after_resume: true, idle_minutes: 10,
        hibernation_minutes: 5, hibernate_on_start: false, nav_bar: "never",
        lock_enabled: false, lock_hash: "", lock_minutes: 0, webrtc_ip_policy: "default",
        download_dir: "", download_ask: false, user_agent: "", gpu: true,
        update_user_agent: true, chrome_major: 0, chrome_checked: "",
        update_check: true, update_checked: "",
        spellcheck: false, spellcheck_language: "auto",
        translator: false, translator_engine: "google", translator_language: "",
        last_service: "", reload_shortcut: "Ctrl+R",
    })
    property var settings: Object.assign({}, defaults)
    // Configuration illisible au démarrage : rien n'est enregistré, pour ne pas l'écraser.
    property bool readOnly: false
    property string current: ""
    property bool quitting: false
    property bool locked: false
    property int total: 0
    property int totalIndirect: 0
    readonly property bool muted: !!settings.dnd
    readonly property string lang: settings.language === "fr" || settings.language === "en"
        ? settings.language : Backend.systemLanguage()
    readonly property bool systemDark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property bool dark: settings.theme === "dark" || (settings.theme !== "light" && systemDark)
    readonly property bool logConsole: Backend.env("VIGIE_CONSOLE") !== ""
    readonly property int iconSize: ({ small: 24, normal: 32, large: 44 })[settings.icon_size] || 32
    readonly property int cellWidth: settings.show_names ? Math.max(76, iconSize + 20) : iconSize + 20
    readonly property int cellHeight: iconSize + 20 + (settings.show_names ? 14 : 0)
    // User-agent du moteur, et celui de Chrome présenté aux sites : version stable actuelle de Chrome
    // (vérifiée chaque semaine, si l'option est active), jamais plus ancienne que le moteur.
    property string engineUserAgent: ""
    readonly property string defaultUserAgent: engineUserAgent
        ? Backend.chromeUserAgent(engineUserAgent, settings.update_user_agent ? Number(settings.chrome_major) || 0 : 0) : ""
    onDefaultUserAgentChanged: {
        for (const k in profiles)
            configureProfile(k)
    }
    // Une session réseau (profil) par clé : l'id du service, ou `session-<nom>` si partagée.
    property var profiles: ({})
    // Vues et infos (icône, domaine, recipe) par id de service.
    property var views: ({})
    property var infos: ({})
    // Notifications envoyées au bureau, par id : { sid, notification }.
    property var sent: ({})
    property var lastNotification: null
    readonly property var serviceModel: services

    // Un élément par service, dans l'ordre de la barre latérale.
    ListModel {
        id: services
    }

    // Texte de l'interface (écrit en français) dans la langue choisie.
    function t(text) {
        return lang === "fr" ? text : Backend.translate(text, lang)
    }

    // --- Services -------------------------------------------------------------------------------

    function serviceAt(i) {
        return JSON.parse(services.get(i).json)
    }
    function indexOf(sid) {
        for (let i = 0; i < services.count; i++)
            if (services.get(i).sid === sid)
                return i
        return -1
    }
    function serviceById(sid) {
        const i = indexOf(sid)
        return i < 0 ? null : serviceAt(i)
    }
    function allServices() {
        const list = []
        for (let i = 0; i < services.count; i++)
            list.push(serviceAt(i))
        return list
    }
    function sessionKey(svc) {
        return svc.session && /^[A-Za-z0-9_-]+$/.test(svc.session) ? "session-" + svc.session : svc.id
    }
    function info(svc) {
        if (!infos[svc.id] || infos[svc.id].for !== JSON.stringify(svc)) {
            const i = JSON.parse(Backend.serviceInfo(JSON.stringify(svc)))
            i.for = JSON.stringify(svc)
            infos[svc.id] = i
        }
        return infos[svc.id]
    }
    function entry(svc) {
        return { sid: svc.id, json: JSON.stringify(svc), direct: 0, indirect: 0, favicon: "", avatar: "" }
    }
    // Le badge s'affiche, sauf pour un service aux notifications coupées si l'option le demande.
    function showsBadge(svc) {
        return !svc.disabled && (!svc.mute_notifications || settings.badges_when_muted)
    }

    function save() {
        if (readOnly) {
            toast.show(t("Configuration illisible au démarrage : modifications non enregistrées."))
            return
        }
        const error = Backend.saveConfig(JSON.stringify(Object.assign({}, settings, { services: allServices() })))
        if (error)
            toast.show(error)
    }
    function setSetting(key, value) {
        const s = Object.assign({}, settings)
        s[key] = value
        settings = s
        if (key === "theme")
            applyTheme()
        if (key === "spellcheck" || key === "spellcheck_language" || key === "user_agent")
            for (const k in profiles)
                configureProfile(k)
        if (key === "dnd" || key === "badges_when_muted")
            refreshTotals()
        save()
    }
    function applyTheme() {
        // Appliqué si la plateforme le permet ; les pages suivent `dark` dans tous les cas.
        Qt.styleHints.colorScheme = settings.theme === "dark" ? Qt.ColorScheme.Dark
            : settings.theme === "light" ? Qt.ColorScheme.Light : Qt.ColorScheme.Unknown
    }

    function addService(svc) {
        svc.id = Backend.newId(svc.name, JSON.stringify(allServices()))
        services.append(entry(svc))
        current = svc.id
        save()
    }
    // Recrée la vue si ce qui la construit change (adresse, recipe, session, user-agent) ; sinon,
    // les réglages s'appliquent sans recharger la page.
    function updateService(svc) {
        const i = indexOf(svc.id)
        if (i < 0)
            return
        const old = serviceAt(i)
        const rebuild = ["url", "recipe", "session", "user_agent"].some(
            k => JSON.stringify(old[k] ?? null) !== JSON.stringify(svc[k] ?? null))
        if (rebuild) {
            services.remove(i)
            services.insert(i, entry(svc))
        } else {
            services.setProperty(i, "json", JSON.stringify(svc))
        }
        if (svc.disabled) {
            services.setProperty(i, "direct", 0)
            services.setProperty(i, "indirect", 0)
        }
        save()
        refreshTotals()
    }
    function setFlag(sid, key, value) {
        const svc = serviceById(sid)
        if (!svc)
            return
        svc[key] = value
        if (!value)
            delete svc[key]
        updateService(svc)
    }
    function editService(sid) {
        const svc = serviceById(sid)
        if (svc)
            settingsDialog.edit(svc, false)
    }
    function deleteService(sid) {
        const i = indexOf(sid)
        if (i < 0)
            return
        services.remove(i)
        if (current === sid)
            current = services.count ? services.get(0).sid : ""
        save()
        refreshTotals()
    }
    function moveService(fromSid, toSid) {
        const from = indexOf(fromSid), to = indexOf(toSid)
        if (from < 0 || to < 0 || from === to)
            return
        services.move(from, to, 1)
        save()
    }
    function importConfig(path) {
        const result = JSON.parse(Backend.importConfig(path))
        if (result.error) {
            toast.show(result.error)
            return
        }
        load(result.config)
        readOnly = false
        save()
        toast.show(t("%1 service(s) importé(s).").arg(services.count))
    }
    function exportConfig(path) {
        const error = Backend.exportConfig(path, JSON.stringify(Object.assign({}, settings, { services: allServices() })))
        toast.show(error || t("Configuration exportée."))
    }
    function load(config) {
        const s = Object.assign({}, config)
        delete s.services
        settings = Object.assign({}, defaults, s)
        services.clear()
        for (const svc of config.services || [])
            services.append(entry(svc))
        // Le dernier service affiché s'il existe encore, sinon le premier.
        current = indexOf(settings.last_service) >= 0 ? settings.last_service
            : services.count ? services.get(0).sid : ""
        applyTheme()
        refreshTotals()
    }
    // Service affiché par l'utilisateur : enregistré pour le prochain démarrage.
    property bool started: false
    onCurrentChanged: {
        if (started && current && settings.last_service !== current)
            setSetting("last_service", current)
    }

    // --- Sessions, badges, notifications, téléchargements -----------------------------------------

    // Profil persistant (Qt 6.9+). Qt ne garde pas le micro et la caméra (permissions « transitoires »,
    // valables pour la seule page qui les a obtenues) : Vigie retient la réponse lui-même, par service
    // (clé `media`, voir askPermission).
    Component {
        id: profilePrototype
        WebEngineProfilePrototype {
            persistentPermissionsPolicy: WebEngineProfile.StoreInMemory
        }
    }
    // Clés de sécurité : Qt WebEngine ne montre rien au début d'une demande, et la page attend en
    // silence (3 minutes au moins). Le script la signale à Vigie, qui ouvre la fenêtre « Clé de
    // sécurité », et l'annule quand Vigie le lui demande (page et cadres). Pas de remplissage
    // automatique (mediation: "conditional") : il resterait en attente sans rien montrer.
    readonly property var webAuthScript: {
        const s = WebEngine.script()
        s.name = "vigie-webauthn"
        s.injectionPoint = WebEngineScript.DocumentCreation
        s.worldId = WebEngineScript.MainWorld
        s.runsOnSubFrames = true
        s.sourceCode = `(() => {
            const c = window.CredentialsContainer?.prototype
            if (!c) return
            const pending = new Set()
            addEventListener("message", e => {
                if (e.data !== "vigie-webauthn-cancel") return
                for (const a of pending) a.abort()
                for (let i = 0; i < frames.length; i++) frames[i].postMessage(e.data, "*")
            })
            for (const f of ["get", "create"]) {
                const native = c[f]
                c[f] = function (options) {
                    if (!options?.publicKey || options.mediation === "conditional") return native.apply(this, arguments)
                    const a = new AbortController()
                    pending.add(a)
                    console.debug("vigie:webauthn-start " + location.hostname)
                    const signal = options.signal ? AbortSignal.any([options.signal, a.signal]) : a.signal
                    return native.call(this, { ...options, signal }).finally(() => {
                        pending.delete(a)
                        console.debug("vigie:webauthn-end")
                    })
                }
            }
            if (window.PublicKeyCredential)
                PublicKeyCredential.isConditionalMediationAvailable = () => Promise.resolve(false)
        })()`
        return s
    }
    // Messages du script ci-dessus, et étapes envoyées par Qt (request) : une fenêtre par vue web.
    function webAuthMessage(web, message) {
        if (message.startsWith("vigie:webauthn-start ")) {
            const w = webAuth(web, null)
            w.site = w.site || message.slice(21)
            w.pending++
        } else if (message === "vigie:webauthn-end" && web.webAuthWindow) {
            if (--web.webAuthWindow.pending <= 0)
                web.webAuthWindow.finish()
        }
    }
    function webAuth(web, request) {
        if (!web.webAuthWindow)
            web.webAuthWindow = webAuthWindow.createObject(root, { app: root, web: web })
        if (request)
            web.webAuthWindow.request = request
        web.webAuthWindow.raise()
        return web.webAuthWindow
    }
    Component {
        id: webAuthWindow
        WebAuthWindow {}
    }
    function profileFor(svc) {
        const key = sessionKey(svc)
        if (!profiles[key]) {
            const p = profilePrototype.createObject(root, { storageName: key }).instance()
            if (!engineUserAgent)
                engineUserAgent = p.httpUserAgent
            p.presentNotification.connect(n => root.notify(key, n))
            p.downloadRequested.connect(d => root.download(d))
            p.userScripts.insert(webAuthScript)
            profiles[key] = p
        }
        profileAgents[key] = svc.user_agent || ""
        configureProfile(key)
        return profiles[key]
    }
    // Version stable actuelle de Chrome (API publique de Google), au plus une fois par semaine.
    function checkChromeVersion() {
        if (!settings.update_user_agent || Backend.env("VIGIE_OFFLINE") !== "")
            return
        const last = Date.parse(settings.chrome_checked || "") || 0
        if (Date.now() - last < 7 * 86400000)
            return
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            const major = xhr.status === 200
                ? parseInt((JSON.parse(xhr.responseText).versions || [{}])[0].version) || 0 : 0
            if (major > 0) {
                console.log("version stable de Chrome : " + major)
                settings = Object.assign({}, settings, { chrome_major: major, chrome_checked: new Date().toISOString() })
                save()
            }
        }
        xhr.open("GET", "https://versionhistory.googleapis.com/v1/chrome/platforms/linux/channels/stable/versions?pageSize=1")
        xhr.send()
    }
    // Nouvelle version de Vigie (release GitHub, ou `main` s'il est compilé depuis les sources), au plus
    // une fois par semaine ; `manual` (bouton des paramètres) : toujours, et dit aussi « à jour ».
    property string updateStatus: ""
    property bool updateManual: false
    // Pour l'onglet Version : mise à jour trouvée ({ kind, version, url }), et déjà installée (release)
    // ou lancée dans un terminal (sources), donc Vigie à redémarrer.
    property var updateFound: null
    property bool updateDone: false
    function checkUpdates(manual) {
        if (!manual && (!settings.update_check || Backend.env("VIGIE_OFFLINE") !== ""
            || Date.now() - (Date.parse(settings.update_checked || "") || 0) < 7 * 86400000))
            return
        updateManual = manual
        updateStatus = t("Recherche des mises à jour…")
        Backend.checkUpdates()
    }
    function updateChecked(kind, version, url, error) {
        if (error) {
            updateStatus = t("Recherche des mises à jour impossible : %1").arg(error)
            if (updateManual)
                toast.show(updateStatus)
            return
        }
        // Mise à jour trouvée : la date n'est pas notée, pour la signaler encore au prochain lancement.
        updateFound = kind === "none" ? null : { kind: kind, version: version, url: url }
        if (kind === "none") {
            settings = Object.assign({}, settings, { update_checked: new Date().toISOString() })
            save()
            updateStatus = t("Vigie est à jour.")
            if (updateManual)
                toast.show(updateStatus)
            return
        }
        const canInstall = JSON.parse(Backend.versionInfo()).canInstall
        // Version de la release, ou de main pour les sources (« 0.4.3+abc1234 » sans changement de version).
        updateStatus = kind === "source" && !canInstall
            ? t("Vigie %1 est disponible : lance ./vigie-rs update.").arg(version)
            : t("Vigie %1 est disponible.").arg(version)
        // Recherche automatique (option « installer automatiquement ») : installée sans attendre ;
        // Redémarrer est proposé à la fin.
        if (canInstall && !updateManual)
            installUpdate(false)
        else if (canInstall)
            toast.show(updateStatus, t("Installer"), () => installUpdate(true))
        else
            toast.show(updateStatus, t("Voir les changements"), () => Qt.openUrlExternally(url))
    }
    // Installée à ta demande (bouton Installer) : Vigie redémarre de lui-même à la fin ; installée
    // automatiquement : Redémarrer est seulement proposé, pour ne pas couper un appel.
    property bool updateByHand: false
    function installUpdate(byHand) {
        updateByHand = byHand
        if (updateFound.kind !== "source") {
            updateStatus = t("Installation de Vigie %1…").arg(updateFound.version)
            Backend.installUpdate()
            return
        }
        // Déjà lancée : sa fenêtre, cachée, se rouvre.
        if (updateWindow) {
            updateWindow.show()
            updateWindow.raise()
            return
        }
        const failed = Backend.updateFromSource()
        if (failed) {
            updateStatus = t("Échec de la mise à jour : %1").arg(failed)
            toast.show(updateStatus)
            return
        }
        updateStatus = t("Mise à jour en cours…")
        updateWindow = updateWindowComponent.createObject(root, { app: root })
    }
    // Mise à jour depuis les sources en cours, ou finie et pas encore fermée.
    property var updateWindow: null
    Component {
        id: updateWindowComponent
        UpdateWindow {}
    }
    function updateInstalled(error) {
        if (error) {
            updateStatus = t("Échec de la mise à jour : %1").arg(error)
            toast.show(updateStatus)
            return
        }
        updateDone = true
        if (updateByHand)
            return restartVigie()
        updateStatus = t("Mise à jour installée : redémarre Vigie pour l'utiliser.")
        toast.show(updateStatus, t("Redémarrer"), restartVigie)
    }
    function restartVigie() {
        const failed = Backend.restart()
        if (failed)
            toast.show(failed)
        else
            quit()
    }
    Timer {
        interval: 6 * 3600000
        running: true
        repeat: true
        onTriggered: {
            root.checkChromeVersion()
            root.checkUpdates(false)
        }
    }
    // User-agent du service, par clé de session.
    property var profileAgents: ({})
    // Google refuse la connexion (« navigateur non sécurisé ») à QtWebEngine déguisé, en Chrome à
    // jour comme en Firefox (que contredisent les Sec-CH-UA de Chromium) ; il l'accepte sous son
    // propre user-agent, « QtWebEngine/… » compris (Eclipse, issue 69, novembre 2026). Sur tout
    // *.google.com (et accounts.youtube.com, étape de la connexion), pour que Google ne voie
    // qu'une identité. User-agent changé après les signaux de Chromium (il l'exige) et hors
    // chargement (il rechargerait la page précédente).
    property var googleSessions: ({})
    function isGoogle(url) {
        return /^https:\/\/(([a-z0-9-]+\.)*google\.com|accounts\.youtube\.com)(\/|$)/.test(String(url))
    }
    function isSignIn(url) {
        return /^https:\/\/accounts\.google\.com\//.test(String(url))
    }
    // Navigation vers Google : vrai si `web` doit l'annuler ; relancée avec le user-agent du moteur.
    function googlePage(svc, url, web) {
        const key = sessionKey(svc)
        if (!isGoogle(url) || googleSessions[key] || !profiles[key])
            return false
        googleSessions[key] = true
        const target = String(url)
        Qt.callLater(() => {
            configureProfile(key)
            web.url = target
        })
        return true
    }
    // Vues sur la page de connexion de Google. Quand l'une la quitte, ou que sa fenêtre se ferme
    // (Android Messages se connecte dans une fenêtre à part), les autres services de la session
    // restés sur la page de connexion, chargée avant, retournent à leur service, connectés.
    property var signIns: []
    // Page chargée (`url` vide : fenêtre fermée) : fin de connexion ; user-agent habituel hors de Google.
    function googlePageLoaded(svc, web, url) {
        const key = sessionKey(svc)
        const i = signIns.indexOf(web)
        if (url && isSignIn(url)) {
            if (i < 0)
                signIns.push(web)
        } else if (i >= 0) {
            signIns.splice(i, 1)
            for (const sid in views)
                if (sessionKey(views[sid].svc) === key)
                    views[sid].afterSignIn(web)
        }
        if (!url || !googleSessions[key] || isGoogle(url))
            return
        Qt.callLater(() => {
            if (!googleSessions[key] || web.loading)
                return
            googleSessions[key] = false
            configureProfile(key)
        })
    }
    // User-agent (celui du moteur sur Google ; sinon celui du service, le global, ou Chrome sans
    // « QtWebEngine/… ») et correcteur.
    function configureProfile(key) {
        const p = profiles[key]
        p.httpUserAgent = googleSessions[key]
            ? engineUserAgent
            : profileAgents[key] || settings.user_agent || defaultUserAgent
        p.spellCheckEnabled = !!settings.spellcheck
        p.spellCheckLanguages = settings.spellcheck_language === "auto" ? ["fr-FR", "en-US"] : [settings.spellcheck_language]
    }

    function setBadge(sid, direct, indirect) {
        const i = indexOf(sid)
        if (i < 0)
            return
        console.log(`[${serviceAt(i).name}] badge ${direct}/${indirect}`)
        services.setProperty(i, "direct", direct)
        services.setProperty(i, "indirect", indirect)
        refreshTotals()
    }
    function setFavicon(sid, url) {
        const i = indexOf(sid)
        if (i >= 0)
            services.setProperty(i, "favicon", String(url))
    }
    // Icône donnée par la recipe (workspace Slack…) : prioritaire sur son logo.
    function setAvatar(sid, url) {
        const i = indexOf(sid)
        if (i >= 0)
            services.setProperty(i, "avatar", String(url))
    }
    // Total du tray, du titre et de D-Bus, sans les services « hors total » ou sans badge.
    function refreshTotals() {
        let direct = 0, indirect = 0
        const list = []
        for (let i = 0; i < services.count; i++) {
            const e = services.get(i), svc = JSON.parse(e.json)
            if (svc.exclude_from_total || !showsBadge(svc))
                continue
            direct += e.direct
            indirect += e.indirect
            if (e.direct || e.indirect)
                list.push([svc.name, e.direct, e.indirect])
        }
        total = direct
        totalIndirect = indirect
        Backend.setUnread(JSON.stringify({ direct: direct, indirect: indirect, services: list, muted: muted }))
    }
    function toggleMute() {
        setSetting("dnd", !settings.dnd)
    }

    // Notification d'une page : rattachée au service de ce profil dont le domaine correspond.
    function notify(key, n) {
        const host = (String(n.origin).match(/^[a-z]+:\/\/([^/:]+)/) || [])[1] || ""
        let svc = null
        for (const s of allServices()) {
            if (sessionKey(s) !== key)
                continue
            const d = info(s).domain
            if (!svc || (d && (host === d || host.endsWith("." + d))))
                svc = s
        }
        if (!svc || svc.disabled)
            return
        if (settings.auto_copy_2fa)
            copyCode(`${n.title} ${n.message}`)
        if (muted || svc.mute_notifications)
            return
        n.show()
        // Contenu masqué (option, ou Vigie verrouillé) : seulement le nom du service.
        const hidden = settings.hide_notification_content || locked
        const title = hidden || !n.title ? svc.name : `${svc.name} : ${n.title}`
        const body = hidden ? t("Nouveau message") : n.message
        const id = Backend.notify(title, body, info(svc).iconPath || "", !svc.mute_sound)
        if (id > 0) {
            sent[id] = { sid: svc.id, notification: n }
        } else {
            lastNotification = { sid: svc.id, notification: n }
            tray.showMessage(title, body)
        }
    }
    function openNotification(entry) {
        if (!entry)
            return
        showWindow()
        current = entry.sid
        entry.notification.click()
    }
    // Code à deux facteurs (4 à 8 chiffres) d'une notification qui contient un des mots-clés.
    function copyCode(text) {
        const lower = text.toLowerCase()
        const keywords = String(settings.codes_keywords).split(",").map(k => k.trim().toLowerCase()).filter(Boolean)
        if (!keywords.some(k => lower.includes(k)))
            return
        const m = text.match(/\b\d{3}[- ]\d{3}\b|\b\d{4,8}\b/)
        if (!m)
            return
        const code = m[0].replace(/[- ]/g, "")
        clipboard.text = code
        clipboard.selectAll()
        clipboard.copy()
        console.log("code à deux facteurs copié")
        toast.show(t("Code %1 copié dans le presse-papiers").arg(code))
    }
    TextEdit {
        id: clipboard
        visible: false
    }

    // Téléchargements : dans le dossier choisi, sinon celui du système (~/Téléchargements) ; ou, sur
    // demande, on demande où enregistrer chaque fichier.
    function download(d) {
        if (settings.download_ask) {
            saveDialog.ask(d)
        } else {
            d.downloadDirectory = settings.download_dir || Backend.downloadsDir()
            startDownload(d)
        }
    }
    function startDownload(d) {
        d.accept()
        d.isFinishedChanged.connect(() => {
            if (d.state === WebEngineDownloadRequest.DownloadCompleted) {
                const file = `${d.downloadDirectory}/${d.downloadFileName}`
                console.log("téléchargé : " + file)
                toast.show(t("Téléchargé : %1").arg(d.downloadFileName), t("Ouvrir"),
                    () => Qt.openUrlExternally("file://" + file))
            } else if (d.state === WebEngineDownloadRequest.DownloadInterrupted) {
                toast.show(t("Téléchargement interrompu : %1").arg(d.downloadFileName))
            }
        })
    }
    FileDialog {
        id: saveDialog
        property var pending: null
        title: root.t("Enregistrer le fichier")
        fileMode: FileDialog.SaveFile
        function ask(d) {
            if (pending)
                pending.cancel()
            pending = d
            // Chemin complet : le dialogue ouvre le dossier et pré-remplit le nom.
            selectedFile = "file://" + Backend.downloadsDir() + "/" + d.suggestedFileName
            open()
        }
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\/\/([A-Za-z]:)/, "$1").replace(/^file:\/\//, ""))
            const slash = path.lastIndexOf("/")
            pending.downloadDirectory = path.slice(0, slash)
            pending.downloadFileName = path.slice(slash + 1)
            root.startDownload(pending)
            pending = null
        }
        onRejected: {
            pending.cancel()
            pending = null
        }
    }

    // --- Fenêtre, permissions, nouvelles fenêtres, veille ------------------------------------------

    function showWindow() {
        root.show()
        root.raise()
        root.requestActivate()
    }
    function toggleWindow() {
        if (root.visible && root.active)
            root.hide()
        else
            showWindow()
    }
    function quit() {
        quitting = true
        Qt.quit()
    }
    function toastMessage(message) {
        toast.show(message)
    }
    function closeSettings() {
        settingsDialog.close()
    }
    function reloadCurrent() {
        if (views[current])
            views[current].reload()
    }
    function openExternal(url) {
        if (/^(https?|mailto):/.test(url))
            Qt.openUrlExternally(url)
        else
            console.log("ouverture refusée : " + url)
    }
    // Traduction de la sélection dans le navigateur (Google Traduction ou DeepL).
    function translate(text) {
        const target = settings.translator_language || lang
        const q = encodeURIComponent(text)
        openExternal(settings.translator_engine === "deepl"
            ? `https://www.deepl.com/translator#auto/${target}/${q}`
            : `https://translate.google.com/?sl=auto&tl=${target}&text=${q}&op=translate`)
    }
    function sameDomain(url, domain) {
        const host = (String(url).match(/^[a-z]+:\/\/([^/:]+)/) || [])[1] || ""
        return !!domain && (host === domain || host.endsWith("." + domain))
    }
    // Fenêtres ouvertes par une page : dans l'app (connexions, appels…) ou dans le navigateur.
    function newWindow(svc, profile, request) {
        const url = String(request.requestedUrl)
        const mode = svc.new_windows || "auto"
        const popup = request.destination === WebEngineNewWindowRequest.InNewDialog
            || request.destination === WebEngineNewWindowRequest.InNewWindow
        if (mode === "internal" || (mode === "auto" && (popup || sameDomain(url, info(svc).domain) || url === "about:blank"))) {
            const w = internalWindow.createObject(root, { app: root, service: svc, profile: profile })
            request.openIn(w.web)
        } else {
            openExternal(url)
        }
    }
    Component {
        id: internalWindow
        InternalWindow {}
    }
    // Micro et caméra : les réponses retenues pour le service, chacun la sienne (`microphone`, `camera` :
    // « allow » ou « deny », d'une session à l'autre). `media` (une seule réponse pour les deux) vient
    // d'une version de développement.
    function mediaAnswer(svc, kind) {
        const s = serviceById(svc.id) || svc
        return s[kind] || s.media || ""
    }
    function mediaKinds(permission) {
        const T = WebEnginePermission.PermissionType
        const kinds = []
        if (permission.permissionType !== T.MediaVideoCapture)
            kinds.push("microphone")
        if (permission.permissionType !== T.MediaAudioCapture)
            kinds.push("camera")
        return kinds
    }
    // Retient la réponse pour ces périphériques (« » : la question reviendra).
    function setMedia(sid, kinds, answer) {
        const svc = serviceById(sid)
        if (!svc)
            return
        if (svc.media) {
            for (const k of ["microphone", "camera"])
                svc[k] = svc[k] || svc.media
            delete svc.media
        }
        for (const k of kinds) {
            if (answer)
                svc[k] = answer
            else
                delete svc[k]
        }
        updateService(svc)
    }
    // Notifications : accordées (coupées ensuite par service). Micro et caméra : selon les réponses
    // retenues (un refus l'emporte, Qt ne pouvant accorder qu'une partie d'une demande), sinon on
    // demande, au-dessus de la fenêtre `window` d'où vient la demande, et on retient la réponse.
    function askPermission(svc, permission, window) {
        const T = WebEnginePermission.PermissionType
        switch (permission.permissionType) {
        case T.Notifications:
            permission.grant()
            break
        case T.MediaAudioCapture:
        case T.MediaVideoCapture:
        case T.MediaAudioVideoCapture: {
            const answers = mediaKinds(permission).map(k => mediaAnswer(svc, k))
            const asking = mediaWindows.find(w => w.svc.id === svc.id && !w.screen)
            if (answers.includes("deny"))
                permission.deny()
            else if (answers.every(a => a === "allow"))
                permission.grant()
            else if (asking)
                asking.add(permission)
            else
                mediaWindows = mediaWindows.concat(permissionWindow.createObject(root, {
                    app: root, svc: svc, permission: permission, transientParent: window || root }))
            break
        }
        // Partage d'écran : demandé à chaque fois, jamais retenu (comme Chrome). Sous Wayland, le
        // système demande ensuite quel écran ou quelle fenêtre ; sous X11, c'est l'écran principal.
        case T.DesktopVideoCapture:
        case T.DesktopAudioVideoCapture:
            mediaWindows = mediaWindows.concat(permissionWindow.createObject(root, {
                app: root, svc: svc, permission: permission, transientParent: window || root }))
            break
        default:
            permission.deny()
        }
    }

    // Toutes les 30 s : reprise après une veille du système (horloge qui a sauté), mise en veille
    // prolongée des services inactifs.
    Timer {
        property double last: Date.now()
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now()
            if (root.settings.reload_after_resume && now - last > root.settings.idle_minutes * 60000) {
                console.log("reprise du système : rechargement des services")
                for (const sid in root.views)
                    root.views[sid].reloadIfAwake()
            }
            last = now
            if (root.settings.hibernation_minutes > 0)
                for (const sid in root.views)
                    root.views[sid].maybeHibernate(now, root.settings.hibernation_minutes)
        }
    }

    // Verrouillage : au démarrage, à la demande, et après N minutes sans utiliser la fenêtre.
    function lock() {
        if (settings.lock_enabled && settings.lock_hash)
            locked = true
    }
    onLockedChanged: console.log(locked ? "verrouillé" : "déverrouillé")
    Timer {
        id: lockTimer
        interval: Math.max(1, root.settings.lock_minutes) * 60000
        running: root.settings.lock_enabled && root.settings.lock_minutes > 0 && !root.active && !root.locked
        onTriggered: root.lock()
    }

    // --- Interface ----------------------------------------------------------------------------------

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: !root.locked

        // Barre latérale : icônes des services, puis recharger, ajouter et paramètres.
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: root.cellWidth + 12
            color: Qt.alpha(palette.windowText, 0.05)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                ListView {
                    id: sidebar
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: services
                    spacing: 4
                    clip: true
                    interactive: contentHeight > height
                    delegate: ServiceIcon {
                        app: root
                    }
                    moveDisplaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 150
                        }
                    }
                }
                ToolButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "⟳"
                    font.pixelSize: 20
                    enabled: services.count > 0
                    onClicked: root.reloadCurrent()
                    ToolTip.visible: hovered
                    ToolTip.text: root.t("Recharger le service (%1)").arg(root.reloadShortcut)
                }
                ToolButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "+"
                    font.pixelSize: 22
                    onClicked: settingsDialog.openCatalogue()
                    ToolTip.visible: hovered
                    ToolTip.text: root.t("Ajouter un service")
                }
                ToolButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "⚙"
                    font.pixelSize: 20
                    onClicked: settingsDialog.openSettings()
                    ToolTip.visible: hovered
                    ToolTip.text: root.t("Paramètres")
                }
            }
        }

        ToolSeparator {
            Layout.fillHeight: true
            padding: 0
        }

        Item {
            id: viewArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Une vue par service activé ; un service désactivé n'est pas chargé du tout.
            Repeater {
                model: services
                delegate: Item {
                    id: slot
                    required property string sid
                    required property string json
                    anchors.fill: parent
                    Loader {
                        anchors.fill: parent
                        active: !JSON.parse(slot.json).disabled
                        sourceComponent: ServiceView {
                            app: root
                            sid: slot.sid
                            json: slot.json
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: services.count === 0
                spacing: 12
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.t("Aucun service")
                    font.pixelSize: 22
                    font.bold: true
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.t("Ajoute WhatsApp, Slack, Gmail… parmi plus de 400 services, ou n'importe quel site.")
                    opacity: 0.7
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.t("Ajouter un service")
                    highlighted: true
                    onClicked: settingsDialog.openCatalogue()
                }
            }

            ColumnLayout {
                readonly property var svc: root.serviceById(root.current)
                anchors.centerIn: parent
                visible: !!svc && !!svc.disabled
                spacing: 12
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: parent.svc ? root.t("%1 est désactivé").arg(parent.svc.name) : ""
                    font.pixelSize: 18
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.t("Activer le service")
                    onClicked: root.setFlag(root.current, "disabled", false)
                }
            }
        }
    }

    // Écran de verrouillage : il cache tout, et ne s'ouvre qu'avec le mot de passe.
    Rectangle {
        anchors.fill: parent
        visible: root.locked
        color: palette.window
        z: 100
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "🔒 " + root.t("Vigie est verrouillé")
                font.pixelSize: 22
                font.bold: true
            }
            TextField {
                id: unlockField
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignHCenter
                echoMode: TextInput.Password
                placeholderText: root.t("Mot de passe")
                focus: root.locked
                onAccepted: unlockButton.clicked()
            }
            Label {
                id: unlockError
                Layout.alignment: Qt.AlignHCenter
                color: "#c01c28"
                visible: text !== ""
            }
            Button {
                id: unlockButton
                Layout.alignment: Qt.AlignHCenter
                text: root.t("Déverrouiller")
                highlighted: true
                onClicked: {
                    if (Backend.checkPassword(unlockField.text, root.settings.lock_hash)) {
                        root.locked = false
                        unlockError.text = ""
                    } else {
                        unlockError.text = root.t("Mot de passe incorrect")
                    }
                    unlockField.text = ""
                }
            }
        }
    }

    SettingsDialog {
        id: settingsDialog
        app: root
    }

    // Recharge le service affiché : son raccourci, sinon celui des paramètres (Ctrl+R), et F5.
    // La page ne reçoit plus ces touches : un service qui se sert de Ctrl+R en prend un autre.
    readonly property string reloadShortcut: (serviceById(current) || {}).reload_shortcut
        || settings.reload_shortcut || defaults.reload_shortcut
    Shortcut {
        // Une même séquence deux fois rendrait le raccourci ambigu (jamais déclenché).
        sequences: root.reloadShortcut === "F5" ? ["F5"] : [root.reloadShortcut, "F5"]
        context: Qt.ApplicationShortcut
        onActivated: root.reloadCurrent()
    }
    // Ctrl+W (Cmd+W sous macOS) : comme la croix de la fenêtre.
    Shortcut {
        sequences: [StandardKey.Close]
        context: Qt.ApplicationShortcut
        onActivated: root.close()
    }

    // Croix de la fenêtre : en arrière-plan (option), sinon on demande avant de quitter.
    onClosing: close => {
        if (quitting)
            return
        close.accepted = false
        if (settings.keep_in_background)
            root.hide()
        else if (!settings.quit_without_asking)
            quitDialog.open()
        else
            quit()
    }
    Dialog {
        id: quitDialog
        anchors.centerIn: Overlay.overlay
        modal: true
        title: root.t("Quitter Vigie ?")
        Label {
            text: root.t("Tu ne recevras plus les notifications de tes services jusqu'à la prochaine ouverture.")
            wrapMode: Text.WordWrap
            width: 360
        }
        footer: DialogButtonBox {
            Button {
                text: root.t("Annuler")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            Button {
                text: root.t("Quitter")
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }
        onAccepted: root.quit()
    }

    // Micro et caméra : une petite fenêtre par service qui demande, au-dessus de la fenêtre qui demande.
    property var mediaWindows: []
    Component {
        id: permissionWindow
        PermissionWindow {}
    }

    // Message bref en bas de la fenêtre (erreurs, confirmations), avec une action facultative.
    Popup {
        id: toast
        property var action: null
        function show(message, actionText, action) {
            toastLabel.text = message
            toastButton.text = actionText || ""
            toast.action = action || null
            open()
            // Le temps de cliquer l'action.
            toastTimer.interval = actionText ? 20000 : 6000
            toastTimer.restart()
        }
        x: (parent.width - width) / 2
        y: parent.height - height - 24
        padding: 12
        contentItem: RowLayout {
            spacing: 12
            Label {
                id: toastLabel
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 520
            }
            Button {
                id: toastButton
                visible: text !== ""
                onClicked: {
                    if (toast.action)
                        toast.action()
                    toast.close()
                }
            }
        }
        Timer {
            id: toastTimer
            interval: 6000
            onTriggered: toast.close()
        }
    }

    Platform.SystemTrayIcon {
        id: tray
        visible: root.settings.show_tray
        icon.source: Backend.trayIcon(root.total > 0 ? "vigie-rs-tray-unread"
            : root.totalIndirect > 0 ? "vigie-rs-tray-indirect" : "vigie-rs-tray")
        tooltip: root.total > 0 ? root.t("Vigie : %1 non lu(s)").arg(root.total) : "Vigie"
        onActivated: reason => {
            if (reason === Platform.SystemTrayIcon.Trigger)
                root.toggleWindow()
        }
        onMessageClicked: root.openNotification(root.lastNotification)
        menu: Platform.Menu {
            Platform.MenuItem {
                text: root.t("Afficher / masquer")
                onTriggered: root.toggleWindow()
            }
            Platform.MenuItem {
                text: root.t("Ne pas déranger")
                checkable: true
                checked: root.muted
                onTriggered: root.toggleMute()
            }
            Platform.MenuItem {
                text: root.t("Verrouiller")
                visible: root.settings.lock_enabled && !!root.settings.lock_hash
                onTriggered: root.lock()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: root.t("Quitter")
                onTriggered: root.quit()
            }
        }
    }

    Connections {
        target: Backend
        function onToggleWindowRequested() {
            root.toggleWindow()
        }
        function onShowWindowRequested() {
            root.showWindow()
        }
        function onToggleMuteRequested() {
            root.toggleMute()
        }
        function onNotificationClicked(id) {
            root.openNotification(root.sent[id])
            delete root.sent[id]
        }
        function onUpdateChecked(kind, version, url, error) {
            root.updateChecked(kind, version, url, error)
        }
        function onUpdateInstalled(error) {
            root.updateInstalled(error)
        }
    }

    Component.onCompleted: {
        const result = JSON.parse(Backend.loadConfig())
        if (result.error) {
            readOnly = true
            load({ services: [] })
            toast.show(result.error)
        } else {
            load(result.config)
        }
        started = true
        checkChromeVersion()
        checkUpdates(false)
        lock()
        Backend.startDesktop()
        // Démarrage minimisé : dans le tray s'il est affiché, sinon réduit dans la barre des tâches.
        if (!settings.start_minimized)
            showWindow()
        else if (!settings.show_tray || !tray.available)
            showMinimized()
    }
}
