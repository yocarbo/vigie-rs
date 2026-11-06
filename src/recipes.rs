//! Script injecté pour une recipe : ses fichiers + le shim + son webview.js en module CommonJS.
use std::{collections::HashMap, fs, path::Path};

use crate::config::Service;

const SHIM: &str = include_str!("shim.js");
pub const MAIN_WORLD: &str = include_str!("main-world.js");

/// Gardé en phase avec test/shim_check.mjs.
pub fn script(dir: Option<&Path>, svc: &Service, dark: bool) -> String {
    let mut files = HashMap::new();
    for path in dir.into_iter().flat_map(|d| fs::read_dir(d).into_iter().flatten().flatten()).map(|e| e.path()) {
        if !matches!(path.extension().and_then(|e| e.to_str()), Some("css" | "js")) {
            continue;
        }
        if let (Some(n), Ok(t)) = (path.file_name().and_then(|n| n.to_str()), fs::read_to_string(&path)) {
            files.insert(n.to_owned(), t);
        }
    }
    let webview_js = files.get("webview.js").cloned().unwrap_or_default();
    let mut settings = serde_json::to_value(svc).expect("JSON");
    settings["isDarkModeEnabled"] = dark.into();
    settings["domain"] = domain(&svc.url).into();
    format!(
        "const __VIGIE_FILES = {};\nconst __VIGIE_SETTINGS = {settings};\nconst __VIGIE_DARK = {dark};\n{SHIM}\n\
         __vigieRun(function (module, exports, require, __dirname) {{\n{webview_js}\n}});\n",
        serde_json::to_string(&files).expect("JSON"),
    )
}

/// La recipe fournit un thème sombre (darkmode.css ou handleDarkMode).
pub fn has_dark(dir: &Path) -> bool {
    dir.join("darkmode.css").exists()
        || fs::read_to_string(dir.join("webview.js")).is_ok_and(|s| s.contains("handleDarkMode"))
}

/// Domaine du service, sous-domaines compris : `app.slack.com` → `slack.com`. Vide pour data:, about:…
pub fn domain(url: &str) -> String {
    let Some(host) = host(url) else { return String::new() };
    let labels: Vec<&str> = host.split('.').collect();
    if host.parse::<std::net::IpAddr>().is_ok() || labels.len() < 2 {
        return host.to_owned();
    }
    labels[labels.len() - 2..].join(".")
}

fn host(url: &str) -> Option<&str> {
    let rest = url.split_once("://")?.1;
    let authority = rest.split(['/', '?', '#']).next()?;
    let host = authority.rsplit('@').next()?.split(':').next()?;
    (!host.is_empty()).then_some(host)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn domaines() {
        assert_eq!(domain("https://app.slack.com/client"), "slack.com");
        assert_eq!(domain("https://web.whatsapp.com"), "whatsapp.com");
        assert_eq!(domain("http://localhost:8123/x"), "localhost");
        assert_eq!(domain("http://user@10.0.0.1:80/"), "10.0.0.1");
        assert_eq!(domain("data:text/html,x"), "");
    }
}
