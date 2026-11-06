//! Mises à jour de Vigie, selon la façon dont il a été compilé :
//! - « release » (archive publiée par la GitHub Action) : la dernière release est téléchargée,
//!   vérifiée (SHA-256) et installée à la place des fichiers actuels ;
//! - « source » (compilé par ./vigie-rs) : Vigie signale que `main` a avancé sur GitHub, et lance
//!   `./vigie-rs update` dans un terminal.
use std::{
    fs,
    io::Read,
    path::{Path, PathBuf},
    time::Duration,
};

use sha2::{Digest, Sha256};

pub const REPO: &str = "yocarbo/vigie-rs";
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
/// Commit compilé (passé par ./vigie-rs ou la GitHub Action), vide sinon.
pub const COMMIT: &str = env!("VIGIE_COMMIT");
/// « release », « source », ou vide (compilation à la main).
pub const CHANNEL: &str = env!("VIGIE_CHANNEL");

/// Une release plus récente que la version en cours.
pub struct Release {
    pub version: String,
    pub page: String,
    archive: String,
    checksum: String,
}

/// Nom de l'archive d'une version, tel que le publie outils/package.sh.
pub fn archive_name(version: &str) -> String {
    format!("vigie-rs-{version}-linux-x86_64.tar.gz")
}

fn agent() -> ureq::Agent {
    ureq::AgentBuilder::new()
        .timeout_connect(Duration::from_secs(10))
        .timeout(Duration::from_secs(120))
        .user_agent(&format!("vigie-rs/{VERSION}"))
        .build()
}

/// 404 (pas encore de release, commit absent de GitHub) : `null`, donc rien de nouveau.
fn get_json(url: &str) -> Result<serde_json::Value, String> {
    match agent().get(url).set("Accept", "application/vnd.github+json").call() {
        Ok(response) => response.into_json().map_err(|e| e.to_string()),
        Err(ureq::Error::Status(404, _)) => Ok(serde_json::Value::Null),
        Err(e) => Err(e.to_string()),
    }
}

/// Binaire en cours ; une fois remplacé par une mise à jour, Linux le suffixe de « (deleted) ».
fn exe() -> Option<PathBuf> {
    let exe = std::env::current_exe().ok()?;
    let path = exe.to_string_lossy();
    Some(PathBuf::from(path.strip_suffix(" (deleted)").unwrap_or(&path)))
}

/// `1.10.0` > `1.9.3` ; le préfixe `v` des tags est ignoré.
pub fn newer(candidate: &str, current: &str) -> bool {
    let parse = |v: &str| -> Vec<u64> {
        v.trim_start_matches('v').split(['.', '-']).take(3).map(|n| n.parse().unwrap_or(0)).collect()
    };
    parse(candidate) > parse(current)
}

/// Dernière release publiée, si elle est plus récente et contient l'archive Linux.
pub fn latest_release() -> Result<Option<Release>, String> {
    let json = get_json(&format!("https://api.github.com/repos/{REPO}/releases/latest"))?;
    let tag = json["tag_name"].as_str().unwrap_or_default();
    let version = tag.trim_start_matches('v').to_owned();
    if version.is_empty() || !newer(&version, VERSION) {
        return Ok(None);
    }
    let asset = |name: &str| {
        json["assets"].as_array().into_iter().flatten().find(|a| a["name"] == name).and_then(|a| a["browser_download_url"].as_str()).map(str::to_owned)
    };
    let name = archive_name(&version);
    let (Some(archive), Some(checksum)) = (asset(&name), asset(&format!("{name}.sha256"))) else {
        return Ok(None);
    };
    let page = json["html_url"].as_str().unwrap_or_default().to_owned();
    Ok(Some(Release { version, page, archive, checksum }))
}

/// Compilé depuis les sources : URL de la comparaison avec `main` si `main` a avancé depuis.
pub fn source_update() -> Result<Option<String>, String> {
    if COMMIT.is_empty() {
        return Ok(None);
    }
    let json = get_json(&format!("https://api.github.com/repos/{REPO}/compare/{COMMIT}...main"))?;
    let ahead = json["status"] == "ahead" || json["status"] == "diverged";
    Ok(ahead.then(|| json["html_url"].as_str().unwrap_or_default().to_owned()))
}

/// Préfixe d'installation : `<préfixe>/bin/vigie-rs`.
pub fn prefix() -> Option<PathBuf> {
    let exe = exe()?.canonicalize().ok()?;
    Some(exe.parent()?.parent()?.to_path_buf())
}

/// Vigie peut remplacer ses propres fichiers (pas une installation système en lecture seule).
pub fn can_install(prefix: &Path) -> bool {
    let probe = prefix.join("bin/.vigie-rs-ecriture");
    let ok = fs::write(&probe, b"").is_ok();
    let _ = fs::remove_file(&probe);
    ok && CHANNEL == "release"
}

fn download(url: &str, dest: &Path) -> Result<(), String> {
    let mut body = Vec::new();
    agent().get(url).call().map_err(|e| e.to_string())?.into_reader().read_to_end(&mut body).map_err(|e| e.to_string())?;
    fs::write(dest, body).map_err(|e| e.to_string())
}

/// L'empreinte attendue (début du fichier .sha256, au format de `sha256sum`) correspond au fichier.
pub fn verify(file: &Path, checksum_file: &Path) -> Result<(), String> {
    let expected = fs::read_to_string(checksum_file).map_err(|e| e.to_string())?;
    let expected = expected.split_whitespace().next().unwrap_or_default().to_lowercase();
    let actual = format!("{:x}", Sha256::digest(fs::read(file).map_err(|e| e.to_string())?));
    if expected == actual {
        Ok(())
    } else {
        Err(format!("empreinte SHA-256 inattendue pour {}", file.display()))
    }
}

/// Télécharge, vérifie et installe une release dans le préfixe en cours.
pub fn install(release: &Release) -> Result<(), String> {
    let prefix = prefix().ok_or("emplacement de Vigie introuvable")?;
    let work = dirs::cache_dir().ok_or("dossier de cache introuvable")?.join("vigie-rs/mise-a-jour");
    let _ = fs::remove_dir_all(&work);
    fs::create_dir_all(&work).map_err(|e| e.to_string())?;
    let (archive, checksum) = (work.join("vigie-rs.tar.gz"), work.join("vigie-rs.tar.gz.sha256"));
    download(&release.archive, &archive)?;
    download(&release.checksum, &checksum)?;
    verify(&archive, &checksum)?;
    install_archive(&archive, &prefix, &work.join("extrait"))?;
    let _ = fs::remove_dir_all(&work);
    Ok(())
}

/// Extrait l'archive (`vigie-rs/bin`, `vigie-rs/share`…) et remplace les fichiers du préfixe : le
/// binaire par renommage (le programme en cours garde l'ancien), les dossiers de données entiers.
pub fn install_archive(archive: &Path, prefix: &Path, staging: &Path) -> Result<(), String> {
    let err = |e: std::io::Error| e.to_string();
    let _ = fs::remove_dir_all(staging);
    fs::create_dir_all(staging).map_err(err)?;
    let file = fs::File::open(archive).map_err(err)?;
    tar::Archive::new(flate2::read::GzDecoder::new(file)).unpack(staging).map_err(err)?;
    let root = staging.join("vigie-rs");
    let new_exe = root.join("bin/vigie-rs");
    if !new_exe.is_file() {
        return Err("archive sans bin/vigie-rs".into());
    }
    // Données d'abord : le nouveau binaire ne démarre qu'au redémarrage.
    for dir in ["share/vigie-rs/recipes", "share/vigie-rs/dictionaries"] {
        let (from, to) = (root.join(dir), prefix.join(dir));
        if !from.is_dir() {
            continue;
        }
        let old = to.with_extension("old");
        let _ = fs::remove_dir_all(&old);
        fs::create_dir_all(to.parent().expect("parent")).map_err(err)?;
        if to.exists() {
            fs::rename(&to, &old).map_err(err)?;
        }
        copy_dir(&from, &to).map_err(err)?;
        let _ = fs::remove_dir_all(&old);
    }
    for file in ["share/applications/io.github.vigie_rs.desktop", "share/icons/hicolor/scalable/apps/io.github.vigie_rs.svg"] {
        let from = root.join(file);
        if from.is_file() {
            let to = prefix.join(file);
            fs::create_dir_all(to.parent().expect("parent")).map_err(err)?;
            fs::copy(&from, &to).map_err(err)?;
        }
    }
    let exe = prefix.join("bin/vigie-rs");
    let tmp = prefix.join("bin/.vigie-rs.nouveau");
    fs::create_dir_all(prefix.join("bin")).map_err(err)?;
    fs::copy(&new_exe, &tmp).map_err(err)?;
    set_executable(&tmp).map_err(err)?;
    fs::rename(&tmp, &exe).map_err(err)?;
    let _ = fs::remove_dir_all(staging);
    Ok(())
}

fn copy_dir(from: &Path, to: &Path) -> std::io::Result<()> {
    fs::create_dir_all(to)?;
    for entry in fs::read_dir(from)? {
        let entry = entry?;
        let target = to.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_dir(&entry.path(), &target)?;
        } else {
            fs::copy(entry.path(), target)?;
        }
    }
    Ok(())
}

#[cfg(unix)]
fn set_executable(path: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(0o755))
}

#[cfg(not(unix))]
fn set_executable(_: &Path) -> std::io::Result<()> {
    Ok(())
}

/// Compilé par ./vigie-rs : son script, dans le dépôt des sources (encore présent) d'où il vient.
pub fn source_script() -> Option<PathBuf> {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let script = dir.join("vigie-rs");
    (CHANNEL == "source" && script.is_file() && dir.join(".git").exists()).then_some(script)
}

/// `./vigie-rs update` dans un terminal, où l'on suit la compilation et tape le mot de passe de sudo ;
/// pour l'installation d'où Vigie a été lancé (PREFIX), sauf s'il tourne depuis le dépôt lui-même.
pub fn update_from_source() -> Result<(), String> {
    let script = source_script().ok_or("dépôt des sources introuvable")?;
    let repo = script.parent().unwrap_or(Path::new("."));
    let prefix = prefix().filter(|p| p.join("bin/vigie-rs").is_file() && p.canonicalize().ok() != repo.canonicalize().ok());
    let command = "[ -z \"$1\" ] || export PREFIX=\"$1\"; \"$0\" update; echo; printf 'Entrée pour fermer… '; read _";
    let args = [
        "sh".to_owned(),
        "-c".to_owned(),
        command.to_owned(),
        script.to_string_lossy().into_owned(),
        prefix.map(|p| p.to_string_lossy().into_owned()).unwrap_or_default(),
    ];
    // ponytail: terminaux courants de Linux ; ajouter le sien ici s'il manque.
    for (terminal, flag) in [("x-terminal-emulator", "-e"), ("konsole", "-e"), ("gnome-terminal", "--"), ("xterm", "-e")] {
        match std::process::Command::new(terminal).arg(flag).args(&args).spawn() {
            Ok(_) => return Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => continue,
            Err(e) => return Err(e.to_string()),
        }
    }
    Err("aucun terminal trouvé (x-terminal-emulator, konsole, gnome-terminal, xterm)".to_owned())
}

/// Relance Vigie (le nouveau binaire) dès que ce processus est terminé et son nom D-Bus libéré :
/// avant, la nouvelle instance ne ferait que réactiver l'ancienne.
pub fn restart() -> Result<(), String> {
    let exe = exe().ok_or("emplacement de Vigie introuvable")?;
    let script = "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; exec \"$0\"";
    std::process::Command::new("sh")
        .args(["-c", script, &exe.to_string_lossy(), &std::process::id().to_string()])
        .spawn()
        .map(|_| ())
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versions() {
        assert!(newer("v0.10.0", "0.9.3"));
        assert!(newer("1.0.0", "0.2.0"));
        assert!(!newer("v0.2.0", "0.2.0"));
        assert!(!newer("0.1.9", "0.2.0"));
    }

    /// Réseau : `cargo test -- --ignored github`. Sans release publiée (404) : rien à installer.
    #[test]
    #[ignore]
    fn github() {
        let release = latest_release().expect("API des releases");
        println!("dernière release : {:?}", release.map(|r| r.version));
    }

    /// Archive fabriquée comme outils/package.sh, vérifiée puis installée dans un préfixe de test.
    #[test]
    fn installation_d_une_archive() {
        let base = std::env::temp_dir().join(format!("vigie-maj-{}", std::process::id()));
        let _ = fs::remove_dir_all(&base);
        let src = base.join("src/vigie-rs");
        fs::create_dir_all(src.join("bin")).unwrap();
        fs::create_dir_all(src.join("share/vigie-rs/recipes/neuve")).unwrap();
        fs::write(src.join("bin/vigie-rs"), b"nouveau binaire").unwrap();
        fs::write(src.join("share/vigie-rs/recipes/neuve/package.json"), b"{}").unwrap();
        let archive = base.join(archive_name("9.9.9"));
        let mut tar = tar::Builder::new(flate2::write::GzEncoder::new(
            fs::File::create(&archive).unwrap(),
            flate2::Compression::default(),
        ));
        tar.append_dir_all("vigie-rs", &src).unwrap();
        tar.into_inner().unwrap().finish().unwrap();
        let sum = format!("{:x}  {}\n", Sha256::digest(fs::read(&archive).unwrap()), archive_name("9.9.9"));
        fs::write(base.join("somme"), &sum).unwrap();
        verify(&archive, &base.join("somme")).expect("empreinte correcte");
        fs::write(base.join("fausse"), "0000  x\n").unwrap();
        assert!(verify(&archive, &base.join("fausse")).is_err(), "empreinte fausse refusée");

        // Préfixe existant : ancien binaire, ancienne recipe, qui doivent être remplacés.
        let prefix = base.join("prefixe");
        fs::create_dir_all(prefix.join("bin")).unwrap();
        fs::create_dir_all(prefix.join("share/vigie-rs/recipes/ancienne")).unwrap();
        fs::write(prefix.join("bin/vigie-rs"), b"ancien").unwrap();
        install_archive(&archive, &prefix, &base.join("extrait")).unwrap();
        assert_eq!(fs::read(prefix.join("bin/vigie-rs")).unwrap(), b"nouveau binaire");
        assert!(prefix.join("share/vigie-rs/recipes/neuve/package.json").is_file());
        assert!(!prefix.join("share/vigie-rs/recipes/ancienne").exists(), "anciennes recipes retirées");
        fs::remove_dir_all(&base).unwrap();
    }
}
