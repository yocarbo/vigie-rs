//! Langues de l'interface : les textes sont écrits en français dans le QML (`t("…")`) et traduits ici.
use std::{collections::HashMap, sync::OnceLock};

/// Français → anglais. Un test vérifie que chaque `t("…")` du QML a sa traduction.
const EN: &[(&str, &str)] = &[
    ("Configuration illisible au démarrage : modifications non enregistrées.", "Unreadable configuration at startup: changes are not saved."),
    ("%1 service(s) importé(s).", "%1 service(s) imported."),
    ("Recherche des mises à jour…", "Checking for updates…"),
    ("Recherche des mises à jour impossible : %1", "Could not check for updates: %1"),
    ("Vigie est à jour.", "Vigie is up to date."),
    ("Une nouvelle version de Vigie est sur GitHub : lance ./vigie-rs update.", "A new version of Vigie is on GitHub: run ./vigie-rs update."),
    ("Une nouvelle version de Vigie est sur GitHub.", "A new version of Vigie is on GitHub."),
    ("Voir les changements", "See the changes"),
    ("Vigie %1 est disponible.", "Vigie %1 is available."),
    ("Installer", "Install"),
    ("Installation de Vigie %1…", "Installing Vigie %1…"),
    ("Échec de la mise à jour : %1", "Update failed: %1"),
    ("Mise à jour installée : redémarre Vigie pour l'utiliser.", "Update installed: restart Vigie to use it."),
    ("Mise à jour lancée dans un terminal : redémarre Vigie une fois qu'elle est finie.", "Update started in a terminal: restart Vigie once it is done."),
    ("Redémarrer", "Restart"),
    ("Version", "Version"),
    ("Installée depuis une release GitHub.", "Installed from a GitHub release."),
    ("Vigie ne peut pas remplacer ses fichiers : il signale les nouvelles versions sans les installer.", "Vigie cannot replace its own files: it reports new versions without installing them."),
    ("Compilée depuis les sources (commit %1). « Installer » lance ./vigie-rs update dans un terminal : récupération de main, compilation, installation.", "Built from source (commit %1). “Install” runs ./vigie-rs update in a terminal: fetches main, builds, installs."),
    ("Compilée depuis les sources (commit %1) : ./vigie-rs update installe les nouveautés de main.", "Built from source (commit %1): ./vigie-rs update installs what is new on main."),
    ("Compilée à la main.", "Built by hand."),
    ("Rechercher les mises à jour chaque semaine (une requête à GitHub)", "Check for updates every week (one request to GitHub)"),
    ("Rechercher une nouvelle version", "Check for a new version"),
    ("Configuration exportée.", "Configuration exported."),
    ("Nouveau message", "New message"),
    ("Code %1 copié dans le presse-papiers", "Code %1 copied to the clipboard"),
    ("Téléchargé : %1", "Downloaded: %1"),
    ("Ouvrir", "Open"),
    ("Téléchargement interrompu : %1", "Download interrupted: %1"),
    ("Enregistrer le fichier", "Save file"),
    ("Recharger le service (F5)", "Reload the service (F5)"),
    ("Ajouter un service", "Add a service"),
    ("Paramètres", "Settings"),
    ("Aucun service", "No service"),
    ("Ajoute WhatsApp, Slack, Gmail… parmi plus de 400 services, ou n'importe quel site.", "Add WhatsApp, Slack, Gmail… among more than 400 services, or any website."),
    ("%1 est désactivé", "%1 is disabled"),
    ("Activer le service", "Enable the service"),
    ("Vigie est verrouillé", "Vigie is locked"),
    ("Mot de passe", "Password"),
    ("Déverrouiller", "Unlock"),
    ("Mot de passe incorrect", "Wrong password"),
    ("Quitter Vigie ?", "Quit Vigie?"),
    ("Tu ne recevras plus les notifications de tes services jusqu'à la prochaine ouverture.", "You will not get your services' notifications until Vigie is opened again."),
    ("Annuler", "Cancel"),
    ("Fermer", "Close"),
    ("Quitter", "Quit"),
    ("le micro et la caméra", "the microphone and the camera"),
    ("la caméra", "the camera"),
    ("le micro", "the microphone"),
    ("%1 veut utiliser %2", "%1 wants to use %2"),
    ("Refuser", "Deny"),
    ("Autoriser", "Allow"),
    ("Vigie : %1 non lu(s)", "Vigie: %1 unread"),
    ("Afficher / masquer", "Show / hide"),
    ("Ne pas déranger", "Do not disturb"),
    ("Verrouiller", "Lock"),
    ("Donne un nom au service.", "Give the service a name."),
    ("L'adresse doit commencer par https:// (ou http://).", "The address must start with https:// (or http://)."),
    ("Remplace la partie {…} de l'adresse, par exemple par le nom de ton espace.", "Replace the {…} part of the address, for instance with your workspace's name."),
    ("Nom de session : lettres, chiffres, - et _ seulement.", "Session name: letters, digits, - and _ only."),
    ("Modifier %1", "Edit %1"),
    ("Nom", "Name"),
    ("Adresse", "Address"),
    ("Recipe", "Recipe"),
    ("aucune (site personnalisé, sans badge)", "none (custom website, no badge)"),
    ("Activé", "Enabled"),
    ("Désactivé : le service reste dans la liste, mais n'est pas chargé.", "Disabled: the service stays in the list, but is not loaded."),
    ("Notifications", "Notifications"),
    ("Son", "Sound"),
    ("Compter dans le total", "Count in the total"),
    ("Décoché : le badge reste sur l'icône, mais hors du tray, du titre et de D-Bus.", "Unchecked: the badge stays on the icon, but out of the tray, the title and D-Bus."),
    ("Veille prolongée", "Hibernation"),
    ("Le service est déchargé quand il n'est pas affiché depuis un moment (voir Paramètres → Général).", "The service is unloaded when it has not been shown for a while (see Settings → General)."),
    ("Barre de navigation", "Navigation bar"),
    ("Nouvelles fenêtres", "New windows"),
    ("Automatique", "Automatic"),
    ("Navigateur par défaut", "Default browser"),
    ("Fenêtre de l'app", "App window"),
    ("Session partagée", "Shared session"),
    ("aucune : session isolée", "none: isolated session"),
    ("Même nom sur plusieurs services (par exemple « google » pour Gmail, Agenda et Chat) : une seule connexion.", "Same name on several services (for instance \"google\" for Gmail, Calendar and Chat): a single sign-in."),
    ("Mode sombre", "Dark mode"),
    ("Toujours (en thème sombre)", "Always (with the dark theme)"),
    ("Jamais", "Never"),
    ("User-agent", "User agent"),
    ("par défaut : celui des paramètres", "default: the one in the settings"),
    ("Supprimer", "Delete"),
    ("Ajouter", "Add"),
    ("Enregistrer", "Save"),
    ("Supprimer %1 ?", "Delete %1?"),
    ("Le service disparaît de Vigie ; sa connexion reste sur le disque.", "The service is removed from Vigie; its sign-in stays on the disk."),
    ("Compter dans le total (tray)", "Count in the total (tray)"),
    ("Ouvrir dans une fenêtre séparée", "Open in a separate window"),
    ("Recharger", "Reload"),
    ("Désactiver le service", "Disable the service"),
    ("Modifier…", "Edit…"),
    ("Précédent", "Back"),
    ("Suivant", "Forward"),
    ("Accueil du service", "Service home"),
    ("Ouvrir dans le navigateur", "Open in the browser"),
    ("%1 est dans une fenêtre séparée", "%1 is in a separate window"),
    ("Remettre dans la fenêtre principale", "Put back in the main window"),
    ("Aucune suggestion", "No suggestion"),
    ("Couper", "Cut"),
    ("Copier", "Copy"),
    ("Coller", "Paste"),
    ("Tout sélectionner", "Select all"),
    ("Traduire « %1 »", "Translate \"%1\""),
    ("Ouvrir le lien dans le navigateur", "Open the link in the browser"),
    ("Copier l'adresse du lien", "Copy the link address"),
    ("Copier l'image", "Copy the image"),
    ("Enregistrer l'image…", "Save the image…"),
    ("Services", "Services"),
    ("Général", "General"),
    ("Apparence", "Appearance"),
    ("Confidentialité", "Privacy"),
    ("Avancé", "Advanced"),
    ("Chaque service est isolé (cookies, stockage), sauf s'il partage une session nommée.", "Each service is isolated (cookies, storage), unless it shares a named session."),
    ("Ajouter…", "Add…"),
    ("%1 (désactivé)", "%1 (disabled)"),
    ("Aucun service pour l'instant", "No service yet"),
    ("Démarrage et fenêtre", "Startup and window"),
    ("Lancer Vigie à l'ouverture de session", "Launch Vigie when logging in"),
    ("Démarrer minimisé (dans la zone de notification)", "Start minimised (in the system tray)"),
    ("Garder Vigie ouvert en arrière-plan quand on ferme la fenêtre", "Keep Vigie running in the background when the window is closed"),
    ("Confirmer avant de quitter Vigie", "Confirm before quitting Vigie"),
    ("Toujours afficher l'icône de Vigie dans la zone de notification", "Always show Vigie's icon in the system tray"),
    ("Langue", "Language"),
    ("Langue de l'interface", "Interface language"),
    ("Langue du système", "System language"),
    ("Veille et reprise", "Sleep and resume"),
    ("Recharger les services après la reprise du système", "Reload the services after the system resumes"),
    ("Délai pour considérer le système comme inactif ou suspendu (minutes)", "Time after which the system is considered idle or suspended (minutes)"),
    ("Veille prolongée des services", "Service hibernation"),
    ("Désactivée", "Off"),
    ("Très rapide (1 min)", "Very fast (1 min)"),
    ("Normale (5 min)", "Normal (5 min)"),
    ("Lente (10 min)", "Slow (10 min)"),
    ("Très lente (30 min)", "Very slow (30 min)"),
    ("Garder les services en veille prolongée au démarrage", "Keep services hibernated at startup"),
    ("Seuls les services où la veille prolongée est activée (clic droit, ou modification du service) sont déchargés quand ils ne sont pas affichés. En veille, un service ne reçoit plus de messages ni de notifications.", "Only services with hibernation turned on (right-click, or editing the service) are unloaded when they are not shown. While hibernated, a service gets no messages or notifications."),
    ("Sauvegarde", "Backup"),
    ("Services et réglages dans un fichier JSON. Les connexions ne sont pas incluses : il faudra se reconnecter.", "Services and settings in a JSON file. Sign-ins are not included: you will have to sign in again."),
    ("Exporter la configuration…", "Export the configuration…"),
    ("Importer une configuration…", "Import a configuration…"),
    ("Ne pas déranger (aucune notification ni son)", "Do not disturb (no notifications or sound)"),
    ("Ne pas afficher le contenu des notifications", "Do not show the content of notifications"),
    ("Afficher les badges des services dont les notifications sont coupées", "Show the badges of services whose notifications are muted"),
    ("Codes à deux facteurs", "Two-factor codes"),
    ("Copier dans le presse-papiers les codes reçus en notification (SMS…)", "Copy codes received in notifications (SMS…) to the clipboard"),
    ("Mots-clés qui signalent un code, séparés par des virgules (majuscules indifférentes)", "Keywords that indicate a code, separated by commas (case-insensitive)"),
    ("Thème", "Theme"),
    ("Système", "System"),
    ("Clair", "Light"),
    ("Sombre", "Dark"),
    ("En sombre, chaque service prend le thème sombre de sa recipe, ou le mode sombre automatique si tu l'actives sur le service.", "When dark, each service takes its recipe's dark theme, or the automatic dark mode if you turn it on for the service."),
    ("Taille des icônes des services", "Size of the service icons"),
    ("Petites", "Small"),
    ("Normales", "Normal"),
    ("Grandes", "Large"),
    ("Afficher le nom du service sous l'icône", "Show the service name under the icon"),
    ("Afficher les services désactivés dans la barre latérale", "Show disabled services in the sidebar"),
    ("Toujours", "Always"),
    ("Selon le service", "Per service"),
    ("Verrouillage", "Lock"),
    ("Activer le verrouillage par mot de passe", "Enable password lock"),
    ("Verrouiller après ce nombre de minutes hors de la fenêtre (0 : au démarrage et à la demande seulement)", "Lock after this many minutes away from the window (0: at startup and on demand only)"),
    ("Changer le mot de passe…", "Change the password…"),
    ("Verrouiller maintenant", "Lock now"),
    ("Le verrouillage cache Vigie et le contenu des notifications. Les services continuent de tourner, et leurs données restent sur le disque, protégées par le chiffrement du disque.", "The lock hides Vigie and the content of notifications. Services keep running, and their data stays on the disk, protected by disk encryption."),
    ("WebRTC (appels)", "WebRTC (calls)"),
    ("Adresses IP exposées aux sites", "IP addresses exposed to websites"),
    ("IP publiques et locales (par défaut)", "Public and local IPs (default)"),
    ("IP publique et IP locale de la route par défaut", "Public IP and local IP of the default route"),
    ("IP publique seulement", "Public IP only"),
    ("Ni IP publique, ni IP locale", "Neither public nor local IP"),
    ("Appliqué au prochain lancement de Vigie. Sans IP exposée, certains appels peuvent échouer.", "Applied the next time Vigie starts. With no exposed IP, some calls may fail."),
    ("Téléchargements", "Downloads"),
    ("Demander où enregistrer à chaque téléchargement", "Ask where to save for every download"),
    ("Choisir un dossier…", "Choose a folder…"),
    ("Toujours demander", "Always ask"),
    ("%1 (dossier par défaut)", "%1 (default folder)"),
    ("Dossier par défaut", "Default folder"),
    ("Tenir à jour la version de Chrome du user-agent (une requête par semaine à Google)", "Keep the Chrome version of the user agent up to date (one request a week to Google)"),
    ("User-agent utilisé : %1", "User agent in use: %1"),
    ("Navigateur", "Browser"),
    ("User-agent par défaut (chaque service peut avoir le sien)", "Default user agent (each service can have its own)"),
    ("Accélération GPU (appliquée au prochain lancement)", "GPU acceleration (applied the next time Vigie starts)"),
    ("Correcteur et traduction", "Spell checking and translation"),
    ("Vérification orthographique", "Spell checking"),
    ("Langue de la vérification", "Spell checking language"),
    ("Français et anglais", "French and English"),
    ("Français", "French"),
    ("Anglais", "English"),
    ("Traducteur : « Traduire » dans le clic droit sur une sélection", "Translator: \"Translate\" in the right-click menu of a selection"),
    ("Service de traduction", "Translation service"),
    ("Traduire vers", "Translate to"),
    ("La langue de l'interface", "The interface language"),
    ("La traduction ouvre le texte sélectionné dans le navigateur, sur le service choisi.", "Translating opens the selected text in the browser, on the chosen service."),
    ("Exporter la configuration", "Export the configuration"),
    ("Configuration (*.json)", "Configuration (*.json)"),
    ("Importer une configuration (remplace tous les services)", "Import a configuration (replaces all services)"),
    ("Dossier des téléchargements", "Downloads folder"),
    ("Mot de passe de verrouillage", "Lock password"),
    ("Le même, pour confirmer", "The same, to confirm"),
    ("Les deux mots de passe diffèrent.", "The two passwords differ."),
    ("Rechercher parmi %1 services", "Search among %1 services"),
    ("Site web personnalisé", "Custom website"),
    ("N'importe quelle URL, sans recipe (pas de badge)", "Any URL, without a recipe (no badge)"),
    ("Lancement au démarrage non pris en charge sur ce système", "Launching at login is not supported on this system"),
];

fn english() -> &'static HashMap<&'static str, &'static str> {
    static MAP: OnceLock<HashMap<&str, &str>> = OnceLock::new();
    MAP.get_or_init(|| EN.iter().copied().collect())
}

/// `text` (en français) dans la langue `lang` ; le français tel quel si la traduction manque.
pub fn translate(text: &str, lang: &str) -> String {
    match lang {
        "en" => english().get(text).copied().unwrap_or(text).to_owned(),
        _ => text.to_owned(),
    }
}

/// « fr » si la langue du système est le français, « en » sinon.
pub fn system_language() -> &'static str {
    let lang = ["LC_ALL", "LC_MESSAGES", "LANG", "LANGUAGE"]
        .iter()
        .filter_map(|v| std::env::var(v).ok())
        .find(|v| !v.is_empty() && v != "C" && v != "POSIX")
        .unwrap_or_default();
    if lang.starts_with("fr") { "fr" } else { "en" }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Chaque texte `t("…")` des fichiers QML a sa traduction anglaise.
    #[test]
    fn traductions_completes() {
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("qml");
        let mut missing = Vec::new();
        for entry in std::fs::read_dir(dir).unwrap().flatten() {
            let text = std::fs::read_to_string(entry.path()).unwrap();
            let mut rest = text.as_str();
            while let Some(i) = rest.find("t(\"") {
                let before = rest[..i].chars().last();
                rest = &rest[i + 3..];
                if before.is_some_and(|c| c.is_alphanumeric() || c == '_') {
                    continue;
                }
                let end = rest.find("\")").expect("t(\"…\") non fermé");
                if !english().contains_key(&rest[..end]) {
                    missing.push(rest[..end].to_owned());
                }
            }
        }
        assert!(missing.is_empty(), "traductions manquantes : {missing:#?}");
        assert_eq!(translate("Paramètres", "en"), "Settings");
        assert_eq!(translate("Paramètres", "fr"), "Paramètres");
    }
}
