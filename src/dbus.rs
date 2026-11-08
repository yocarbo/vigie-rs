//! Linux : instance unique, interface io.github.vigie_rs.Vigie (compteurs pour les autres
//! applications, commandes) et notifications du bureau (org.freedesktop.Notifications).
use std::{collections::HashMap, sync::Mutex, sync::OnceLock};

use cxx_qt::CxxQtThread;
use zbus::{blocking::Connection, interface, zvariant::Value};

use crate::backend::qobject::Backend;

pub const NAME: &str = "io.github.vigie_rs";
const PATH: &str = "/io/github/vigie_rs";
const IFACE: &str = "io.github.vigie_rs.Vigie";
const FDO: &str = "org.freedesktop.Notifications";
const FDO_PATH: &str = "/org/freedesktop/Notifications";

static CONN: OnceLock<Connection> = OnceLock::new();

/// Prend le nom D-Bus de l'app. S'il est déjà pris, affiche l'instance en cours et renvoie false.
pub fn claim() -> bool {
    // Ni remplacer une instance existante, ni se laisser remplacer par une nouvelle.
    let built = zbus::blocking::connection::Builder::session()
        .map(|b| b.allow_name_replacements(false).replace_existing_names(false))
        .and_then(|b| b.name(NAME))
        .and_then(|b| b.build());
    match built {
        Ok(conn) => {
            let _ = CONN.set(conn);
            true
        }
        Err(zbus::Error::NameTaken) => {
            if let Ok(conn) = Connection::session() {
                let _ = conn.call_method(Some(NAME), PATH, Some(IFACE), "Activate", &());
            }
            false
        }
        Err(e) => {
            eprintln!("D-Bus indisponible : {e}");
            true
        }
    }
}

struct Vigie {
    qt: Mutex<CxxQtThread<Backend>>,
    direct: u32,
    indirect: u32,
    services: Vec<(String, u32, u32)>,
    muted: bool,
}

impl Vigie {
    fn queue(&self, f: impl FnOnce(std::pin::Pin<&mut Backend>) + Send + 'static) {
        if let Ok(qt) = self.qt.lock() {
            let _ = qt.queue(f);
        }
    }
}

#[interface(name = "io.github.vigie_rs.Vigie")]
impl Vigie {
    fn toggle_window(&self) {
        self.queue(|b| b.toggle_window_requested());
    }

    /// Affiche la fenêtre (lancement d'une seconde instance).
    fn activate(&self) {
        self.queue(|b| b.show_window_requested());
    }

    fn toggle_mute(&self) {
        self.queue(|b| b.toggle_mute_requested());
    }

    fn toggle_to_talk(&self) {}

    #[zbus(property)]
    fn unread_direct_message_count(&self) -> u32 {
        self.direct
    }

    #[zbus(property)]
    fn unread_indirect_message_count(&self) -> u32 {
        self.indirect
    }

    #[zbus(property)]
    fn unread_services(&self) -> Vec<(String, u32, u32)> {
        self.services.clone()
    }

    #[zbus(property)]
    fn muted(&self) -> bool {
        self.muted
    }
}

/// Publie l'interface, et transmet les clics sur les notifications au QML.
pub fn serve(qt: CxxQtThread<Backend>) {
    let Some(conn) = CONN.get() else { return };
    let clicks = qt.clone();
    let online = qt.clone();
    let vigie = Vigie { qt: Mutex::new(qt), direct: 0, indirect: 0, services: Vec::new(), muted: false };
    // Connexion à Internet revenue (NetworkManager, état 70 : CONNECTED_GLOBAL), au démarrage de la
    // session ou en sortie de veille : un signal, rien à interroger en boucle.
    std::thread::spawn(move || {
        let Ok(system) = Connection::system() else { return };
        let nm = "org.freedesktop.NetworkManager";
        let proxy = zbus::blocking::Proxy::new(&system, nm, "/org/freedesktop/NetworkManager", nm);
        let Ok(signals) = proxy.and_then(|p| p.receive_signal("StateChanged")) else { return };
        for msg in signals {
            if msg.body().deserialize::<u32>().is_ok_and(|state| state == 70) {
                let _ = online.queue(|b| b.network_online());
            }
        }
    });
    if let Err(e) = conn.object_server().at(PATH, vigie) {
        eprintln!("D-Bus {PATH} : {e}");
    }
    std::thread::spawn(move || {
        let proxy = zbus::blocking::Proxy::new(conn, FDO, FDO_PATH, FDO);
        let Ok(signals) = proxy.and_then(|p| p.receive_signal("ActionInvoked")) else { return };
        for msg in signals {
            if let Ok((id, _action)) = msg.body().deserialize::<(u32, String)>() {
                let _ = clicks.queue(move |b| b.notification_clicked(id as i32));
            }
        }
    });
}

pub fn set_unread(direct: u32, indirect: u32, services: Vec<(String, u32, u32)>, muted: bool) {
    let Some(conn) = CONN.get() else { return };
    let Ok(iface) = conn.object_server().interface::<_, Vigie>(PATH) else { return };
    let mut v = iface.get_mut();
    let changed = (v.direct != direct, v.indirect != indirect, v.services != services, v.muted != muted);
    (v.direct, v.indirect, v.services, v.muted) = (direct, indirect, services, muted);
    let emitter = iface.signal_emitter();
    let sent = zbus::block_on(async {
        if changed.0 {
            v.unread_direct_message_count_changed(emitter).await?;
        }
        if changed.1 {
            v.unread_indirect_message_count_changed(emitter).await?;
        }
        if changed.2 {
            v.unread_services_changed(emitter).await?;
        }
        if changed.3 {
            v.muted_changed(emitter).await?;
        }
        zbus::Result::Ok(())
    });
    if let Err(e) = sent {
        eprintln!("D-Bus PropertiesChanged : {e}");
    }
}

/// Envoie une notification au bureau ; renvoie son id (0 en cas d'échec).
pub fn notify(app_name: &str, title: &str, body: &str, icon: &str, sound: bool) -> u32 {
    let Some(conn) = CONN.get() else { return 0 };
    let mut hints: HashMap<&str, Value> = HashMap::new();
    hints.insert("desktop-entry", Value::from(NAME));
    if !icon.is_empty() {
        hints.insert("image-path", Value::from(icon));
    }
    if !sound {
        hints.insert("suppress-sound", Value::from(true));
    }
    let app_icon = if icon.is_empty() { NAME } else { icon };
    let actions = vec!["default", "Ouvrir"];
    let reply = conn.call_method(
        Some(FDO),
        FDO_PATH,
        Some(FDO),
        "Notify",
        &(app_name, 0u32, app_icon, title, body, actions, hints, -1i32),
    );
    match reply.and_then(|r| r.body().deserialize::<u32>()) {
        Ok(id) => id,
        Err(e) => {
            eprintln!("notification : {e}");
            0
        }
    }
}
