//! Objet `Backend` exposé au QML (singleton) : configuration, recipes, icônes, bureau.
//! Les échanges se font en JSON : le QML garde l'état de l'interface, Rust lit et écrit les fichiers.
#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        type Backend = super::BackendRust;

        #[qinvokable]
        #[cxx_name = "version"]
        fn version(self: &Backend) -> QString;

        /// `{"config": {...}}`, ou `{"error": "..."}` si le fichier est illisible.
        #[qinvokable]
        #[cxx_name = "loadConfig"]
        fn load_config(self: &Backend) -> QString;

        /// Message d'erreur, vide si tout va bien.
        #[qinvokable]
        #[cxx_name = "saveConfig"]
        fn save_config(self: &Backend, json: &QString) -> QString;

        /// `{"recipeDir", "icon", "recipeDark", "domain"}` pour un service.
        #[qinvokable]
        #[cxx_name = "serviceInfo"]
        fn service_info(self: &Backend, json: &QString) -> QString;

        /// Script du monde isolé (recipe + shim), vide si le service n'a pas de recipe.
        #[qinvokable]
        #[cxx_name = "recipeScript"]
        fn recipe_script(self: &Backend, json: &QString, dark: bool) -> QString;

        #[qinvokable]
        #[cxx_name = "mainWorldScript"]
        fn main_world_script(self: &Backend) -> QString;

        /// `[{"name", "url", "dir", "icon"}]`, trié par nom.
        #[qinvokable]
        #[cxx_name = "catalogue"]
        fn catalogue(self: &Backend) -> QString;

        #[qinvokable]
        #[cxx_name = "newId"]
        fn new_id(self: &Backend, name: &QString, services: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "exportConfig"]
        fn export_config(self: &Backend, path: &QString, json: &QString) -> QString;

        /// Comme loadConfig, pour un fichier exporté.
        #[qinvokable]
        #[cxx_name = "importConfig"]
        fn import_config(self: &Backend, path: &QString) -> QString;

        /// URL du fichier de l'icône du tray `name` (vigie-rs-tray, -unread, -indirect).
        #[qinvokable]
        #[cxx_name = "trayIcon"]
        fn tray_icon(self: &Backend, name: &QString) -> QString;

        /// Variable d'environnement (vide si absente).
        #[qinvokable]
        #[cxx_name = "env"]
        fn env(self: &Backend, name: &QString) -> QString;

        /// Linux : publie l'interface D-Bus et écoute les clics sur les notifications.
        #[qinvokable]
        #[cxx_name = "startDesktop"]
        fn start_desktop(self: Pin<&mut Backend>);

        /// `{"direct", "indirect", "services": [[nom, direct, indirect]], "muted"}`.
        #[qinvokable]
        #[cxx_name = "setUnread"]
        fn set_unread(self: &Backend, json: &QString);

        /// Notification du bureau (Linux) : renvoie son id, ou -1 si le QML doit passer par le tray.
        #[qinvokable]
        #[cxx_name = "notify"]
        fn notify(self: &Backend, title: &QString, body: &QString, icon: &QString, sound: bool) -> i32;

        /// Lancement à l'ouverture de session (Linux : ~/.config/autostart).
        #[qinvokable]
        #[cxx_name = "autostartEnabled"]
        fn autostart_enabled(self: &Backend) -> bool;

        /// Message d'erreur, vide si tout va bien.
        #[qinvokable]
        #[cxx_name = "setAutostart"]
        fn set_autostart(self: &Backend, on: bool) -> QString;

        /// Empreinte Argon2 du mot de passe de verrouillage (format PHC).
        #[qinvokable]
        #[cxx_name = "hashPassword"]
        fn hash_password(self: &Backend, password: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "checkPassword"]
        fn check_password(self: &Backend, password: &QString, hash: &QString) -> bool;

        /// Texte de l'interface (écrit en français) dans la langue `lang`.
        #[qinvokable]
        #[cxx_name = "translate"]
        fn translate(self: &Backend, text: &QString, lang: &QString) -> QString;

        /// « fr » ou « en », d'après la langue du système.
        #[qinvokable]
        #[cxx_name = "systemLanguage"]
        fn system_language(self: &Backend) -> QString;

        #[qinvokable]
        #[cxx_name = "downloadsDir"]
        fn downloads_dir(self: &Backend) -> QString;

        /// User-agent de Chrome : celui du moteur (plateforme comprise), sans « QtWebEngine/… », à la
        /// version `major` si elle est plus récente (0 : celle du moteur).
        #[qinvokable]
        #[cxx_name = "chromeUserAgent"]
        fn chrome_user_agent(self: &Backend, engine: &QString, major: i32) -> QString;

        /// `{"version", "commit", "channel", "canInstall"}` : de quoi afficher et choisir la mise à jour ;
        /// `canInstall` : « Installer » marche (release dans un dossier modifiable, ou dépôt des sources).
        #[qinvokable]
        #[cxx_name = "versionInfo"]
        fn version_info(self: &Backend) -> QString;

        /// En tâche de fond ; résultat par `updateChecked`.
        #[qinvokable]
        #[cxx_name = "checkUpdates"]
        fn check_updates(self: Pin<&mut Backend>);

        /// Installe la release trouvée par checkUpdates, en tâche de fond ; résultat par `updateInstalled`.
        #[qinvokable]
        #[cxx_name = "installUpdate"]
        fn install_update(self: Pin<&mut Backend>);

        /// Compilé depuis les sources : `./vigie-rs update` en tâche de fond, suivi par `updateLog` ;
        /// message d'erreur, vide s'il est lancé.
        #[qinvokable]
        #[cxx_name = "updateFromSource"]
        fn update_from_source(self: &Backend) -> QString;

        /// Sortie de la mise à jour depuis les sources (étapes en lignes « ==> », fin par « ==> code N »).
        #[qinvokable]
        #[cxx_name = "updateLog"]
        fn update_log(self: &Backend) -> QString;

        /// Relance Vigie juste après sa fermeture ; message d'erreur, vide si tout va bien.
        #[qinvokable]
        #[cxx_name = "restart"]
        fn restart(self: &Backend) -> QString;

        /// `kind` : « release » (installable), « source » (./vigie-rs update), « none » ; `url` : page à
        /// ouvrir ; `error` : échec de la vérification.
        #[qsignal]
        #[cxx_name = "updateChecked"]
        fn update_checked(self: Pin<&mut Backend>, kind: QString, version: QString, url: QString, error: QString);

        #[qsignal]
        #[cxx_name = "updateInstalled"]
        fn update_installed(self: Pin<&mut Backend>, error: QString);

        #[qsignal]
        #[cxx_name = "toggleWindowRequested"]
        fn toggle_window_requested(self: Pin<&mut Backend>);

        #[qsignal]
        #[cxx_name = "showWindowRequested"]
        fn show_window_requested(self: Pin<&mut Backend>);

        #[qsignal]
        #[cxx_name = "toggleMuteRequested"]
        fn toggle_mute_requested(self: Pin<&mut Backend>);

        #[qsignal]
        #[cxx_name = "notificationClicked"]
        fn notification_clicked(self: Pin<&mut Backend>, id: i32);

        /// Connexion à Internet revenue (NetworkManager) : les pages restées en erreur se rechargent.
        #[qsignal]
        #[cxx_name = "networkOnline"]
        fn network_online(self: Pin<&mut Backend>);
    }

    impl cxx_qt::Threading for Backend {}
}

use std::{
    fs,
    path::{Path, PathBuf},
    pin::Pin,
};

use cxx_qt_lib::QString;
use serde_json::{json, Value};

use crate::{
    config::{self, Config, Service},
    i18n, icons, recipes, update,
};

/// Empreinte Argon2 (format PHC, sel aléatoire) : seule elle est enregistrée, jamais le mot de passe.
pub fn hash_password(password: &str) -> String {
    use argon2::password_hash::{rand_core::OsRng, PasswordHasher, SaltString};
    let salt = SaltString::generate(&mut OsRng);
    argon2::Argon2::default().hash_password(password.as_bytes(), &salt).map(|h| h.to_string()).unwrap_or_default()
}

pub fn check_password(password: &str, hash: &str) -> bool {
    use argon2::password_hash::{PasswordHash, PasswordVerifier};
    PasswordHash::new(hash).is_ok_and(|h| argon2::Argon2::default().verify_password(password.as_bytes(), &h).is_ok())
}

/// Dossier des téléchargements : celui du bureau (XDG, ~/Téléchargements en français), sinon
/// ~/Téléchargements s'il existe, sinon ~/Downloads.
fn downloads_dir() -> PathBuf {
    if let Some(dir) = dirs::download_dir() {
        return dir;
    }
    let home = dirs::home_dir().unwrap_or_default();
    let fr = home.join("Téléchargements");
    if fr.is_dir() { fr } else { home.join("Downloads") }
}

/// `Chrome/<version>` du user-agent du moteur remplacé par `Chrome/<major>.0.0.0` (forme réduite de
/// Chrome) si `major` est plus récent ; la mention « QtWebEngine/… » retirée.
pub fn chrome_user_agent(engine: &str, major: u32) -> String {
    let ua: Vec<&str> = engine.split(' ').filter(|t| !t.starts_with("QtWebEngine/")).collect();
    ua.iter()
        .map(|token| match token.strip_prefix("Chrome/") {
            Some(version) => {
                let own: u32 = version.split('.').next().and_then(|m| m.parse().ok()).unwrap_or(0);
                format!("Chrome/{}.0.0.0", own.max(major))
            }
            None => (*token).to_owned(),
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// Fichier d'ouverture de session (Linux seulement).
fn autostart_file() -> Option<PathBuf> {
    if cfg!(target_os = "linux") {
        dirs::config_dir().map(|d| d.join("autostart/io.github.vigie_rs.desktop"))
    } else {
        None
    }
}

pub struct BackendRust {
    config_path: PathBuf,
    /// Release trouvée par la dernière vérification, à installer.
    release: std::sync::Arc<std::sync::Mutex<Option<update::Release>>>,
}

impl Default for BackendRust {
    fn default() -> Self {
        Self { config_path: config::path(), release: Default::default() }
    }
}

fn q(s: impl AsRef<str>) -> QString {
    QString::from(s.as_ref())
}

/// URL `file://` d'un chemin local, pour les `source` d'images du QML.
pub fn file_url(path: &Path) -> String {
    let p = path.to_string_lossy().replace('\\', "/");
    let encoded: String = p
        .chars()
        .map(|c| match c {
            '%' => "%25".to_owned(),
            ' ' => "%20".to_owned(),
            '#' => "%23".to_owned(),
            '?' => "%3F".to_owned(),
            c => c.to_string(),
        })
        .collect();
    if encoded.starts_with('/') { format!("file://{encoded}") } else { format!("file:///{encoded}") }
}

fn config_json(result: Result<Config, String>) -> String {
    match result {
        Ok(c) => json!({ "config": c }).to_string(),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

const TRAY_ICONS: [(&str, &[u8]); 3] = [
    ("vigie-rs-tray", include_bytes!("../assets/tray/vigie-rs-tray.svg")),
    ("vigie-rs-tray-unread", include_bytes!("../assets/tray/vigie-rs-tray-unread.svg")),
    ("vigie-rs-tray-indirect", include_bytes!("../assets/tray/vigie-rs-tray-indirect.svg")),
];

impl qobject::Backend {
    pub fn version(&self) -> QString {
        q(env!("CARGO_PKG_VERSION"))
    }

    pub fn load_config(&self) -> QString {
        q(config_json(config::load(&self.config_path)))
    }

    pub fn save_config(&self, json: &QString) -> QString {
        let result = serde_json::from_str::<Config>(&json.to_string())
            .map_err(|e| e.to_string())
            .and_then(|c| config::save(&self.config_path, &c));
        q(result.err().unwrap_or_default())
    }

    fn recipe_dir(&self, svc: &Service) -> Option<PathBuf> {
        svc.recipe.as_ref().map(|r| config::resolve(&self.config_path, r)).filter(|d| d.is_dir())
    }

    pub fn service_info(&self, json: &QString) -> QString {
        let Ok(svc) = serde_json::from_str::<Service>(&json.to_string()) else { return q("{}") };
        let dir = self.recipe_dir(&svc);
        let icon = dir.as_ref().and_then(|d| icons::trimmed(&d.join("icon.svg")));
        q(json!({
            "recipeDir": dir.as_ref().map(|d| d.to_string_lossy().into_owned()).unwrap_or_default(),
            "icon": icon.as_deref().map(file_url).unwrap_or_default(),
            "iconPath": icon.as_ref().map(|p| p.to_string_lossy().into_owned()).unwrap_or_default(),
            "recipeDark": dir.as_deref().is_some_and(recipes::has_dark),
            "domain": recipes::domain(&svc.url),
        })
        .to_string())
    }

    pub fn recipe_script(&self, json: &QString, dark: bool) -> QString {
        let Ok(svc) = serde_json::from_str::<Service>(&json.to_string()) else { return QString::default() };
        match self.recipe_dir(&svc) {
            Some(dir) => q(recipes::script(Some(&dir), &svc, dark)),
            None => QString::default(),
        }
    }

    pub fn main_world_script(&self) -> QString {
        q(recipes::MAIN_WORLD)
    }

    pub fn catalogue(&self) -> QString {
        let list: Vec<Value> = config::catalogue(&self.config_path)
            .into_iter()
            .map(|r| {
                json!({
                    "name": r.name,
                    "url": r.url,
                    "dir": r.dir.to_string_lossy(),
                    "icon": if r.icon.is_file() { file_url(&r.icon) } else { String::new() },
                })
            })
            .collect();
        q(Value::from(list).to_string())
    }

    pub fn new_id(&self, name: &QString, services: &QString) -> QString {
        let taken: Vec<Service> = serde_json::from_str(&services.to_string()).unwrap_or_default();
        q(config::new_id(&name.to_string(), &taken))
    }

    pub fn export_config(&self, path: &QString, json: &QString) -> QString {
        let result = serde_json::from_str::<Config>(&json.to_string())
            .map_err(|e| e.to_string())
            .and_then(|c| config::save(Path::new(&path.to_string()), &c));
        q(result.err().unwrap_or_default())
    }

    pub fn import_config(&self, path: &QString) -> QString {
        q(config_json(config::load(Path::new(&path.to_string()))))
    }

    pub fn tray_icon(&self, name: &QString) -> QString {
        let name = name.to_string();
        let Some(dir) = dirs::cache_dir().map(|d| d.join("vigie-rs/tray")) else { return QString::default() };
        let Some((_, svg)) = TRAY_ICONS.iter().find(|(n, _)| *n == name) else { return QString::default() };
        let path = dir.join(format!("{name}.svg"));
        if fs::read(&path).ok().as_deref() != Some(*svg) {
            let _ = fs::create_dir_all(&dir).and_then(|_| fs::write(&path, svg));
        }
        q(file_url(&path))
    }

    pub fn env(&self, name: &QString) -> QString {
        q(std::env::var(name.to_string()).unwrap_or_default())
    }

    pub fn start_desktop(self: Pin<&mut Self>) {
        #[cfg(target_os = "linux")]
        {
            use cxx_qt::Threading;
            crate::dbus::serve(self.qt_thread());
        }
        #[cfg(not(target_os = "linux"))]
        let _ = self;
    }

    pub fn set_unread(&self, json: &QString) {
        #[cfg(target_os = "linux")]
        {
            #[derive(serde::Deserialize)]
            struct Unread {
                direct: u32,
                indirect: u32,
                services: Vec<(String, u32, u32)>,
                muted: bool,
            }
            if let Ok(u) = serde_json::from_str::<Unread>(&json.to_string()) {
                crate::dbus::set_unread(u.direct, u.indirect, u.services, u.muted);
            }
        }
        #[cfg(not(target_os = "linux"))]
        let _ = json;
    }

    pub fn autostart_enabled(&self) -> bool {
        autostart_file().is_some_and(|f| f.is_file())
    }

    pub fn set_autostart(&self, on: bool) -> QString {
        let Some(file) = autostart_file() else {
            return q(i18n::translate("Lancement au démarrage non pris en charge sur ce système", "fr"));
        };
        let result = if on {
            let exe = std::env::current_exe().and_then(|e| e.canonicalize()).map_err(|e| e.to_string());
            exe.and_then(|exe| {
                let entry = format!(
                    "[Desktop Entry]\nType=Application\nName=Vigie\nExec=\"{}\"\nIcon=io.github.vigie_rs\nX-GNOME-Autostart-enabled=true\n",
                    exe.display()
                );
                fs::create_dir_all(file.parent().expect("dossier")).and_then(|_| fs::write(&file, entry)).map_err(|e| e.to_string())
            })
        } else {
            match fs::remove_file(&file) {
                Err(e) if e.kind() != std::io::ErrorKind::NotFound => Err(e.to_string()),
                _ => Ok(()),
            }
        };
        q(result.err().unwrap_or_default())
    }

    pub fn hash_password(&self, password: &QString) -> QString {
        q(hash_password(&password.to_string()))
    }

    pub fn check_password(&self, password: &QString, hash: &QString) -> bool {
        check_password(&password.to_string(), &hash.to_string())
    }

    pub fn translate(&self, text: &QString, lang: &QString) -> QString {
        q(i18n::translate(&text.to_string(), &lang.to_string()))
    }

    pub fn system_language(&self) -> QString {
        q(i18n::system_language())
    }

    pub fn downloads_dir(&self) -> QString {
        let dir = downloads_dir();
        let _ = fs::create_dir_all(&dir);
        q(dir.to_string_lossy())
    }

    pub fn version_info(&self) -> QString {
        let can_install = update::source_script().is_some() || update::prefix().is_some_and(|p| update::can_install(&p));
        q(json!({
            "version": update::VERSION,
            "commit": update::COMMIT.get(..7).unwrap_or(update::COMMIT),
            "channel": update::CHANNEL,
            "canInstall": can_install,
        })
        .to_string())
    }

    pub fn check_updates(self: Pin<&mut Self>) {
        use cxx_qt::{CxxQtType, Threading};
        let (qt, slot) = (self.qt_thread(), self.rust().release.clone());
        std::thread::spawn(move || {
            let (kind, version, url, error) = if update::CHANNEL == "source" {
                match update::source_update() {
                    Ok(Some((url, version))) => ("source", version, url, String::new()),
                    Ok(None) => ("none", String::new(), String::new(), String::new()),
                    Err(e) => ("none", String::new(), String::new(), e),
                }
            } else {
                match update::latest_release() {
                    Ok(Some(release)) => {
                        let found = ("release", release.version.clone(), release.page.clone(), String::new());
                        *slot.lock().expect("verrou") = Some(release);
                        found
                    }
                    Ok(None) => ("none", String::new(), String::new(), String::new()),
                    Err(e) => ("none", String::new(), String::new(), e),
                }
            };
            let _ = qt.queue(move |b| b.update_checked(q(kind), q(version), q(url), q(error)));
        });
    }

    pub fn install_update(self: Pin<&mut Self>) {
        use cxx_qt::{CxxQtType, Threading};
        let (qt, slot) = (self.qt_thread(), self.rust().release.clone());
        std::thread::spawn(move || {
            let result = match slot.lock().expect("verrou").as_ref() {
                Some(release) => update::install(release),
                None => Err("aucune mise à jour à installer".to_owned()),
            };
            let error = result.err().unwrap_or_default();
            let _ = qt.queue(move |b| b.update_installed(q(error)));
        });
    }

    pub fn update_from_source(&self) -> QString {
        q(update::update_from_source().err().unwrap_or_default())
    }

    pub fn update_log(&self) -> QString {
        q(update::source_log_tail())
    }

    pub fn restart(&self) -> QString {
        q(update::restart().err().unwrap_or_default())
    }

    pub fn chrome_user_agent(&self, engine: &QString, major: i32) -> QString {
        q(chrome_user_agent(&engine.to_string(), major.max(0) as u32))
    }

    pub fn notify(&self, title: &QString, body: &QString, icon: &QString, sound: bool) -> i32 {
        #[cfg(target_os = "linux")]
        {
            let id = crate::dbus::notify("Vigie", &title.to_string(), &body.to_string(), &icon.to_string(), sound);
            if id > 0 {
                return id as i32;
            }
        }
        let _ = (title, body, icon, sound);
        -1
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn user_agent_chrome() {
        let qt = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) QtWebEngine/6.10.2 Chrome/134.0.6998.208 Safari/537.36";
        let chrome = |v| format!("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{v}.0.0.0 Safari/537.36");
        assert_eq!(super::chrome_user_agent(qt, 157), chrome(157), "version de Chrome plus récente");
        assert_eq!(super::chrome_user_agent(qt, 0), chrome(134), "inconnue : celle du moteur");
        assert_eq!(super::chrome_user_agent(qt, 120), chrome(134), "jamais plus ancienne que le moteur");
    }

    #[test]
    fn mot_de_passe() {
        let hash = super::hash_password("secret");
        assert!(hash.starts_with("$argon2"), "{hash}");
        assert!(super::check_password("secret", &hash));
        assert!(!super::check_password("Secret", &hash));
        assert!(!super::check_password("secret", "pas une empreinte"));
        // Empreinte utilisée par test/e2e.sh (mot de passe « secret »).
        println!("EMPREINTE {hash}");
    }

    #[test]
    fn urls_de_fichiers() {
        assert_eq!(super::file_url(std::path::Path::new("/a b/c#d.png")), "file:///a%20b/c%23d.png");
    }
}
