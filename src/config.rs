//! Configuration (settings.json : thème + services) et catalogue des recipes Vigie.
use std::{
    fs,
    io::ErrorKind,
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Theme {
    #[default]
    System,
    Light,
    Dark,
}

#[derive(Clone, Default, Deserialize, Serialize, PartialEq)]
pub struct Service {
    pub id: String,
    pub name: String,
    pub url: String,
    /// Dossier de la recipe, relatif au fichier de configuration.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recipe: Option<PathBuf>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub user_agent: Option<String>,
    /// Même valeur sur plusieurs services = mêmes cookies et stockage. Absent = isolé.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session: Option<String>,
    /// Absent = auto : oui si la recipe fournit un thème sombre.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dark_mode: Option<bool>,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub mute_notifications: bool,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub mute_sound: bool,
    /// Badge gardé sur l'icône du service, mais hors du total (tray, titre, D-Bus).
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub exclude_from_total: bool,
    #[serde(default, skip_serializing_if = "NewWindows::is_auto")]
    pub new_windows: NewWindows,
    /// Réglages gérés par l'interface seule (désactivé, veille, barre de navigation…) : conservés tels quels.
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

/// Où s'ouvrent les liens `target=_blank` et les `window.open`.
#[derive(Clone, Copy, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum NewWindows {
    /// Liens cliqués → navigateur ; fenêtres ouvertes par script (connexions OAuth…) → fenêtre de l'app.
    #[default]
    Auto,
    Browser,
    Internal,
}

impl NewWindows {
    fn is_auto(&self) -> bool {
        *self == NewWindows::Auto
    }
}

#[derive(Clone, Default, Deserialize, Serialize)]
pub struct Config {
    #[serde(default)]
    pub theme: Theme,
    #[serde(default)]
    pub services: Vec<Service>,
    /// La croix de la fenêtre quitte sans confirmation (absent : on demande).
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub quit_without_asking: bool,
    /// Réglages gérés par l'interface seule (démarrage, tray, notifications…) : conservés tels quels.
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

impl Config {
    pub fn flag(&self, key: &str, default: bool) -> bool {
        self.extra.get(key).and_then(|v| v.as_bool()).unwrap_or(default)
    }

    pub fn text(&self, key: &str) -> &str {
        self.extra.get(key).and_then(|v| v.as_str()).unwrap_or_default()
    }
}

/// Accepte aussi l'ancien format : un simple tableau de services.
#[derive(Deserialize)]
#[serde(untagged)]
enum File {
    Config(Config),
    Services(Vec<Service>),
}

pub fn path() -> PathBuf {
    std::env::var_os("VIGIE_CONFIG")
        .map(PathBuf::from)
        .unwrap_or_else(|| dirs::config_dir().unwrap_or_default().join("vigie-rs/settings.json"))
}

pub fn load(path: &Path) -> Result<Config, String> {
    let err = |e: &dyn std::fmt::Display| format!("{} : {e}", path.display());
    let text = match fs::read_to_string(path) {
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(Config::default()),
        r => r.map_err(|e| err(&e))?,
    };
    let mut config = match serde_json::from_str(&text).map_err(|e| err(&e))? {
        File::Config(c) => c,
        File::Services(services) => Config { services, ..Default::default() },
    };
    let mut seen = std::collections::HashSet::new();
    config.services.retain(|s| {
        // L'id devient un nom de dossier : rien qui puisse sortir du répertoire de données.
        let ok = valid_key(&s.id) && seen.insert(s.id.clone());
        if !ok {
            eprintln!("service ignoré, id invalide ou en double : {:?}", s.id);
        }
        ok
    });
    Ok(config)
}

/// Écrit dans un fichier temporaire puis renomme : une erreur ne laisse jamais une config tronquée.
pub fn save(path: &Path, config: &Config) -> Result<(), String> {
    let err = |e: &dyn std::fmt::Display| format!("{} : {e}", path.display());
    if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
        fs::create_dir_all(dir).map_err(|e| err(&e))?;
    }
    let tmp = path.with_extension("json.tmp");
    let json = serde_json::to_string_pretty(config).map_err(|e| err(&e))?;
    fs::write(&tmp, json + "\n").map_err(|e| err(&e))?;
    fs::rename(&tmp, path).map_err(|e| err(&e))
}

pub fn valid_key(s: &str) -> bool {
    !s.is_empty() && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

/// Chemin d'une recipe : relatif au dossier du fichier de configuration, sinon cherchée par son
/// nom dans le catalogue (configuration importée depuis une autre machine).
pub fn resolve(config: &Path, recipe: &Path) -> PathBuf {
    let path = config.parent().unwrap_or(Path::new(".")).join(recipe);
    match recipe.file_name() {
        Some(name) if !path.exists() => recipes_base(config).0.join(name),
        _ => path,
    }
}

/// Id libre dérivé du nom : « Google Chat » → `google-chat`, puis `google-chat-2`…
pub fn new_id(name: &str, taken: &[Service]) -> String {
    let slug: String = name
        .to_lowercase()
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect();
    let base = match slug.trim_matches('-') {
        "" => "service".to_owned(),
        s => s.to_owned(),
    };
    (1..)
        .map(|n| if n == 1 { base.clone() } else { format!("{base}-{n}") })
        .find(|id| taken.iter().all(|s| &s.id != id))
        .expect("id libre")
}

pub struct Recipe {
    /// Tel qu'écrit dans settings.json : relatif au fichier de configuration, sinon absolu.
    pub dir: PathBuf,
    pub name: String,
    pub url: String,
    pub icon: PathBuf,
}

#[derive(Deserialize)]
struct Package {
    name: String,
    #[serde(default)]
    config: PackageConfig,
}

#[derive(Default, Deserialize)]
struct PackageConfig {
    #[serde(default, rename = "serviceURL")]
    service_url: String,
}

/// Dossier `recipes/` : à côté du fichier de configuration, sinon en remontant depuis le binaire :
/// `bin/vigie-rs` ou `target/debug/vigie-rs` dans le projet, `share/vigie-rs/recipes` une fois
/// installé (`/usr/bin/vigie-rs` → `/usr/share/vigie-rs/recipes`).
fn recipes_base(config: &Path) -> (PathBuf, bool) {
    let next_to_config = config.parent().unwrap_or(Path::new(".")).join("recipes");
    if next_to_config.is_dir() {
        return (next_to_config, true);
    }
    (near_exe("recipes").unwrap_or(next_to_config), false)
}

/// Dossier `name` du projet ou de l'installation, en remontant depuis le binaire :
/// `<projet>/name` (bin/ ou target/…), ou `<préfixe>/share/vigie-rs/name`.
pub fn near_exe(name: &str) -> Option<PathBuf> {
    let exe = std::env::current_exe().ok().and_then(|e| e.canonicalize().ok())?;
    exe.ancestors()
        .skip(1)
        .take(3)
        .flat_map(|d| [d.join(name), d.join("share/vigie-rs").join(name)])
        .find(|d| d.is_dir())
}

/// Recipes Vigie disponibles, triées par nom.
pub fn catalogue(config: &Path) -> Vec<Recipe> {
    let (base, relative) = recipes_base(config);
    let mut recipes: Vec<Recipe> = fs::read_dir(&base)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            let dir = entry.path();
            let pkg: Package = serde_json::from_str(&fs::read_to_string(dir.join("package.json")).ok()?).ok()?;
            Some(Recipe {
                dir: if relative { Path::new("recipes").join(entry.file_name()) } else { dir.clone() },
                name: pkg.name,
                url: pkg.config.service_url,
                icon: dir.join("icon.svg"),
            })
        })
        .collect();
    recipes.sort_by_key(|r| r.name.to_lowercase());
    recipes
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_et_ancien_format() {
        let taken = [Service { id: "google-chat".into(), ..Default::default() }];
        assert_eq!(new_id("Google Chat", &taken), "google-chat-2");
        assert_eq!(new_id("  Été ! ", &[]), "t");
        assert_eq!(new_id("***", &[]), "service");
        assert!(!valid_key("../x") && valid_key("session_1"));
        let old: File = serde_json::from_str(r#"[{"id":"a","name":"A","url":"https://a"}]"#).unwrap();
        assert!(matches!(old, File::Services(ref s) if s.len() == 1));
        let dupes: Config = serde_json::from_str(r#"{"services":[{"id":"a","name":"A","url":"u"},{"id":"a","name":"B","url":"u"}]}"#).unwrap();
        let tmp = std::env::temp_dir().join(format!("vigie-test-{}.json", std::process::id()));
        save(&tmp, &dupes).unwrap();
        assert_eq!(load(&tmp).unwrap().services.len(), 1, "id en double ignoré");
        // Réglages inconnus de Rust (gérés par l'interface) : conservés à l'enregistrement.
        let extra: Config = serde_json::from_str(r#"{"dnd":true,"services":[{"id":"a","name":"A","url":"u","disabled":true}]}"#).unwrap();
        save(&tmp, &extra).unwrap();
        let back = load(&tmp).unwrap();
        assert!(back.flag("dnd", false) && back.services[0].extra["disabled"] == true);
        std::fs::remove_file(&tmp).unwrap();
    }
}
