mod backend;
mod config;
#[cfg(target_os = "linux")]
mod dbus;
mod i18n;
mod icons;
mod qtapp;
mod recipes;
mod update;

use cxx_qt_lib::{QQmlApplicationEngine, QString, QUrl};

/// Réglages lus par Chromium à son démarrage seulement (un changement demande de relancer Vigie).
fn chromium_settings(config: &config::Config) {
    let mut flags = std::env::var("QTWEBENGINE_CHROMIUM_FLAGS").unwrap_or_default();
    let policy = config.text("webrtc_ip_policy");
    if ["default_public_and_private_interfaces", "default_public_interface_only", "disable_non_proxied_udp"]
        .contains(&policy)
    {
        flags.push_str(&format!(" --force-webrtc-ip-handling-policy={policy}"));
    }
    if !config.flag("gpu", true) {
        flags.push_str(" --disable-gpu --disable-gpu-compositing");
    }
    std::env::set_var("QTWEBENGINE_CHROMIUM_FLAGS", flags.trim());
    // Dictionnaires du correcteur (*.bdic), générés par ./vigie-rs à partir de ceux de hunspell.
    if std::env::var_os("QTWEBENGINE_DICTIONARIES_PATH").is_none() {
        if let Some(dir) = config::near_exe("dictionaries") {
            std::env::set_var("QTWEBENGINE_DICTIONARIES_PATH", dir);
        }
    }
}

/// Thème des pages (prefers-color-scheme), que Chromium ne prend pas de Qt : celui de Vigie. Lu au
/// démarrage du moteur (premier profil), donc après l'application, qui connaît le thème du système.
// ponytail: fixé au lancement ; changer de thème demande de relancer Vigie pour les pages.
fn page_color_scheme(theme: config::Theme) {
    let dark = match theme {
        config::Theme::Dark => true,
        config::Theme::Light => false,
        config::Theme::System => qtapp::ffi::vigie_system_dark(),
    };
    if dark {
        let flags = std::env::var("QTWEBENGINE_CHROMIUM_FLAGS").unwrap_or_default();
        std::env::set_var("QTWEBENGINE_CHROMIUM_FLAGS", format!("{flags} --blink-settings=preferredColorScheme=0").trim());
    }
}

fn main() {
    // Déjà lancé : l'instance en cours s'affiche, celle-ci s'arrête.
    #[cfg(target_os = "linux")]
    if !dbus::claim() {
        return;
    }
    let config = config::load(&config::path()).unwrap_or_default();
    chromium_settings(&config);
    qtapp::ffi::vigie_prepare();
    let app = qtapp::ffi::vigie_application();
    page_color_scheme(config.theme);
    let icons = icons::app_icon_dir().map(|d| d.to_string_lossy().into_owned()).unwrap_or_default();
    qtapp::ffi::vigie_window_icon(&QString::from(icons.as_str()));
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/Vigie/qml/Main.qml"));
    }
    let code = qtapp::ffi::vigie_exec();
    // Le moteur QML avant l'application.
    drop(engine);
    drop(app);
    std::process::exit(code);
}
