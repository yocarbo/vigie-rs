<p align="center">
  <img src="assets/io.github.vigie_rs.svg" alt="Vigie logo: an eye on a blue tile" width="128" height="128">
</p>

<h1 align="center">Vigie (vigie-rs)</h1>

All your messaging apps in one window, in Rust: Qt 6 (Qt Quick Controls) + Qt WebEngine (Chromium), bound with [cxx-qt](https://github.com/KDAB/cxx-qt). Each service runs in its own web view, with its own session. A catalogue of 440 "recipes" knows how to read each service's unread count, apply a dark theme, and so on. Audio and video calls work (WhatsApp, Meet…), since the engine is Chromium.

It runs on Linux (developed on KDE Plasma); Qt and Qt WebEngine also exist on Windows and macOS, where everything but the D-Bus interface and launch at login should work (not tested yet).

It is inspired by [Ferdium](https://github.com/ferdium/ferdium-app), and its recipes come from [ferdium-recipes](https://github.com/ferdium/ferdium-recipes): see [Acknowledgements](#acknowledgements).

## Running

```bash
sudo apt install libqt6webenginequick6 qml6-module-qtwebengine qml6-module-qtwebchannel \
  qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-dialogs \
  qml6-module-qtquick-effects qml6-module-qt-labs-platform   # once; already there on most KDE Plasma installs
docker build -t vigie-rs-dev .          # once: the build environment
./vigie-rs                              # your services: ~/.config/vigie-rs/settings.json
VIGIE_CONFIG=example/services.json ./vigie-rs   # two local test services (changes are saved there)
```

`./vigie-rs` builds the release binary in the container (`outils/release.sh`), copies it to `bin/`, converts the French and English hunspell dictionaries for the spell checker into `dictionaries/`, and runs it on the host. It can be run from anywhere, including through a symlink in `~/.local/bin`. Launching it a second time shows the running instance instead of starting another one.

Services and settings are read from and saved to `~/.config/vigie-rs/settings.json` (`$XDG_CONFIG_HOME` is honoured). A missing file gives an empty app, and everything can be added from the interface.

### Installing

```bash
./vigie-rs install     # binary in /usr/bin, recipes in /usr/share/vigie-rs, menu entry and icon (asks for sudo)
./vigie-rs uninstall   # removes them; settings and sign-ins stay
```

`PREFIX=/usr/local ./vigie-rs install` installs under another prefix. Once installed, Vigie is in the applications menu (`io.github.vigie_rs.desktop`), and `vigie-rs` runs from anywhere. The window's icon is built into the binary, so it shows even when Vigie is not installed.

### Updating

From the sources:

```bash
./vigie-rs update      # git pull, rebuild, and reinstall if Vigie is installed in $PREFIX
```

A Vigie built by `./vigie-rs` knows its commit and its checkout: once a week, it asks GitHub whether `main` has moved on. If so, **Install** opens a terminal (`x-terminal-emulator`, Konsole, GNOME Terminal or xterm) that runs `./vigie-rs update`, where you follow the build and type the sudo password; then **Restart** relaunches Vigie.

From a release: each `vX.Y.Z` tag makes the GitHub Action (`.github/workflows/release.yml`) run the tests, build Vigie in the container and publish `vigie-rs-X.Y.Z-linux-x86_64.tar.gz` with its SHA-256. Extracted into a folder you can write to, Vigie updates itself:

```bash
tar xzf vigie-rs-X.Y.Z-linux-x86_64.tar.gz --strip-components=1 -C ~/.local   # ~/.local/bin/vigie-rs
```

Once a week, it looks at the latest release. When there is a newer one, it offers to install it: it downloads the archive, checks its SHA-256, replaces its files and restarts. The checksum catches a broken download, not a forged release, since it comes from the same place as the archive. The binary uses the system's Qt, so it needs the packages above, with Qt 6.10 or later (Ubuntu 26.04). A release extracted into a folder Vigie cannot write to (`/usr`) only says that a new version is out.

Both checks can be turned off, and run by hand, in Settings → Version. To publish a release, set the new version in `Cargo.toml`, commit and push, then:

```bash
git tag v0.3.0 && git push origin v0.3.0   # the tag must match the version in Cargo.toml
```

## Interface

- **Sidebar**:
  - each service's icon, in a fixed box (small, normal or large): its recipe's logo (trimmed of its blank margins), otherwise the site's favicon, otherwise its initials; optionally its name underneath;
  - a red badge for direct unread messages, a dot for indirect ones;
  - 🔕 or 🔇 when the service's notifications or sound are muted; disabled services greyed out (or hidden);
  - three buttons at the bottom: reload the current service (⟳, F5 or Ctrl+R), add a service (+), settings (⚙).
- **Reordering**: hold the left button on an icon and drop it onto another one; it takes that place, and the order is saved.
- **Right-click on an icon**: toggle Notifications, Sound, "Count in total (tray)" and Hibernation; open in a separate window, reload, enable or disable, edit.
- **Count in total**: when unchecked, the service keeps its badge in the sidebar, but its unread messages are no longer added to the tray (icon and tooltip), the window title or the D-Bus counters.
- **Tray**: a grey eye at rest, red with direct unread messages, blue with indirect ones only. Its menu shows or hides the window, toggles Do not disturb, locks Vigie, or quits.
- **Window title**: the total of unread messages and the current service, for example "(3) WhatsApp — Vigie".
- **Last service**: Vigie opens again on the service that was shown when it was closed.
- **Right-click in a page**: spelling suggestions, cut, copy, paste, open or copy a link, copy or save an image, translate the selection, back, forward, reload.
- **Navigation bar** (never, always, or per service): back, forward, service home, address, open in the browser.
- **Ctrl+W** closes the window like its close button.
- **Ctrl+R** (and F5) reloads the current service. The page no longer gets that key: a service that uses Ctrl+R itself can take another shortcut in its editor, and Settings → General changes the default one. A shortcut is written like `Ctrl+Shift+R` or `Alt+R`.

Every change is saved to the configuration file and applied without restarting, except GPU acceleration and the WebRTC IP policy, read when Vigie starts.

### Settings

- **Services**: the list. A click opens the editor (name, URL, enabled, notifications, sound, total, hibernation, navigation bar, new windows, shared session, dark mode, user agent, reload shortcut), where the service can also be deleted. **Add** (`+`): catalogue of the 440 services with search, or "Custom website" for any URL.
- **General**:
  - launch at login (Linux: `~/.config/autostart`), start minimised, keep running in the background when the window is closed, confirm before quitting (on by default), always show the tray icon;
  - interface language: system, French or English;
  - the shortcut that reloads the current service (Ctrl+R by default);
  - reload the services after the system resumes (detected when the clock jumps by more than the idle delay, 10 minutes by default);
  - hibernation: services with hibernation turned on are unloaded after 1, 5, 10 or 30 minutes without being shown, and can stay unloaded at startup; while unloaded, a service gets no messages;
  - configuration export and import.
- **Version**: the current version and how it was built (release, or source with its commit), **Check for a new version**, then **Install** and **Restart** when there is one (see [Updating](#updating)), and the weekly check.
- **Notifications**: Do not disturb, hide the content of notifications, badges of muted services, two-factor codes (a 4 to 8-digit code in a notification that contains one of the keywords is copied to the clipboard).
- **Appearance**: theme, icon size, names under icons, disabled services in the sidebar, navigation bar.
- **Privacy**: password lock (at startup, on demand, or after N minutes away from the window; only an Argon2 hash is stored), WebRTC IP policy.
- **Advanced**: downloads (into the system's downloads folder by default, `~/Téléchargements` or `~/Downloads`, or into a chosen folder, or ask every time), default user agent and its automatic update, GPU acceleration, spell checking (French and/or English), translator (Google Translate or DeepL, in the browser).

The lock hides Vigie and the content of notifications; services keep running and their data stays on the disk, protected by disk encryption.

### Notifications and sound

- Notification permission is granted to every service; muting is then per service (editor or right-click).
- On Linux, notifications go straight to the desktop (`org.freedesktop.Notifications`), with the service's name and logo, so they work with or without a tray. Elsewhere they go through the tray.
- Clicking a notification shows the window on that service and runs the page's `onclick`, which usually opens the conversation.
- The tray and the `ToggleMute` D-Bus method mute all notifications and sound at once.

### Microphone and camera

When a service asks for the microphone or the camera (a call, a voice message…), Vigie asks you first: Allow or Deny. The answer holds until Vigie is closed, so a mistaken refusal is not permanent. Other permissions are denied, except notifications.

### New windows

Per-service setting:
- **Automatic** (default): a window opened by a page as a popup, or on the service's own domain (sign-in, calls…), opens in an app window, with `window.opener` and the service's session; other links open in the browser.
- **Default browser**, or **App window**, for everything.

The recipe does not run in these windows: it is restricted to the service's domain and to pages without `window.opener`.

"Open in a separate window" moves the service into its own window without reloading the page. Closing that window puts it back in the main window.

### Sessions: isolated by default, shareable

Each service has its own cookies and storage (`~/.local/share/vigie-rs/QtWebEngine/<id>`). Give several services the same session name, for example `google` for Gmail, Calendar and Chat, and they share a single sign-in (`~/.local/share/vigie-rs/QtWebEngine/session-google`): once you sign in to Google in one of them (or in the window Android Messages opens for it), the others still on Google's sign-in page return to their service, signed in. Changing this setting requires signing in again.

Sites see an ordinary, up-to-date Chrome: the "QtWebEngine" mention is removed from the user agent, and its Chrome version is the current stable one. Vigie asks [Google's public version API](https://versionhistory.googleapis.com/v1/chrome/platforms/linux/channels/stable/versions) at most once a week (Settings → Advanced, can be turned off), and never presents a version older than its engine's. A service's own user agent, or the default one set in the settings, takes precedence.

Google refuses to sign in QtWebEngine in disguise ("This browser or app may not be secure"): as an up-to-date Chrome, even with matching `Sec-CH-UA` brands, and as Firefox, which Chromium's `Sec-CH-UA` headers contradict. It accepts the engine's own user agent, "QtWebEngine/…" included (reported by the Eclipse browser, November 2026). On every `*.google.com` page and on `accounts.youtube.com`, Vigie presents that one, so Google sees a single identity, and the up-to-date Chrome again once a page elsewhere has loaded. Google also refuses sign-ins after many attempts in a row; waiting a while helps. A session already refused keeps Google's cookies from those visits: give its services a new session name (or delete its folder) to start from scratch.

### Dark mode

When Vigie is dark (Dark theme, or System with a dark desktop):
- pages see `prefers-color-scheme: dark`, so sites with their own dark theme use it, as in a browser. Chromium reads this at startup: after changing the theme, restart Vigie for the pages to follow;
- if the service's recipe has a dark theme (`handleDarkMode`, failing that `darkmode.css`), it is applied;
- otherwise, with the service's "Dark mode" set to "Always", Chromium's automatic dark mode is used.

Slack's recipe has no `darkmode.css`: Ferdium's, written for Slack's former interface, repainted part of the new one in grey over Slack's own dark theme (Preferences → Themes), which Slack keeps per device.

WhatsApp's recipe no longer unregisters the page's service workers when it unloads, as Ferdium's does: in Qt WebEngine the unregistration completes on every reload, and WhatsApp then signs out.

The Light and Dark themes change Vigie's own colours only where Qt lets an app override the desktop's colour scheme; the pages follow them in every case.

### Backup

Settings → General → Backup exports and imports the configuration (services and settings) as JSON, without sign-ins. On import, a recipe not found next to the configuration is looked up by name in the catalogue, so an exported file works on another machine.

Sign-ins (cookies, site storage) stay in `~/.local/share/vigie-rs/`. They are protected by disk encryption (LUKS) while the machine is off.

## Recipes

A recipe teaches Vigie how to read a service. Without one, a site still works ("Custom website"), but without an unread count or a tailored dark theme. Each recipe is a folder in `recipes/`:

| File | Purpose |
|---|---|
| `package.json` | service name and default URL (`config.serviceURL`), used by the catalogue |
| `icon.svg` | sidebar and notification icon |
| `webview.js` | the core: a script injected into the service's page, called with the `Vigie` object |
| `service.css`, `darkmode.css` | visual tweaks, and the dark theme when the recipe provides one |
| `webview-unsafe.js` | rare: a script that needs the page's own variables |
| `index.js` | settings for the original Electron app, ignored by Vigie |

`webview.js` reads the page every 2 seconds and reports the unread count:

```js
module.exports = Vigie => {
  Vigie.loop(() => Vigie.setBadge(document.querySelectorAll('.unread').length));
};
```

Recipes run in an isolated JavaScript world (Qt WebEngine's `ApplicationWorld`): they see the page's DOM but not its variables, and the site cannot see them. They talk to Vigie through QWebChannel. They can break when a site changes its markup; the recipe then needs updating.

## Configuration

```json
{
  "theme": "system",
  "services": [
    { "id": "gmail", "name": "Gmail", "url": "https://mail.google.com", "recipe": "recipes/gmail", "session": "google" },
    { "id": "wiki", "name": "My wiki", "url": "https://wiki.example.org", "dark_mode": true }
  ]
}
```

- `id`: letters, digits, `-`, `_`; it is also the name of the data folder. A duplicate id is ignored.
- `recipe`: relative to the configuration file, otherwise looked up by name in the catalogue.
- Optional: `recipe`, `session`, `dark_mode` (absent: automatic), `user_agent` (absent: the default one), `mute_notifications`, `mute_sound`, `exclude_from_total`, `new_windows` (`auto`, `browser`, `internal`), `disabled`, `hibernate`, `nav_bar`, `reload_shortcut` (absent: the default one).
- At the top level, next to `theme` and `services`: the settings of the Settings window, for example `quit_without_asking`, `keep_in_background`, `start_minimized`, `show_tray`, `dnd`, `hide_notification_content`, `icon_size`, `language`, `hibernation_minutes`, `download_dir`, `download_ask`, `update_user_agent`, `chrome_major`, `update_check`, `update_checked`, `lock_enabled`, `lock_hash`, `last_service`, `reload_shortcut` (see `qml/Main.qml`, `defaults`). Keys unknown to Rust are kept as they are.
- The old format, a plain array of services, is still read.
- The catalogue is read from `recipes/` next to the configuration file, otherwise from the project's `recipes/` (found by walking up from the binary), or from `share/vigie-rs/recipes` once installed (`/usr/share/vigie-rs/recipes`).
- An unreadable configuration file is never overwritten: Vigie starts empty and saves nothing.

Environment variables: `VIGIE_CONFIG` (configuration file, default `~/.config/vigie-rs/settings.json`), `VIGIE_CONSOLE=1` (JS console of pages and recipes), `VIGIE_OFFLINE=1` (no automatic Chrome version or update check, used by the tests).

## D-Bus (Linux)

The `io.github.vigie_rs.Vigie` interface is published on `/io/github/vigie_rs`, under the application's name (`io.github.vigie_rs`), which also makes Vigie single-instance. It provides:
- the properties `UnreadDirectMessageCount`, `UnreadIndirectMessageCount`, `UnreadServices` and `Muted`;
- the methods `ToggleWindow`, `Activate`, `ToggleMute` and `ToggleToTalk`.

```bash
qdbus6 io.github.vigie_rs /io/github/vigie_rs
```

## Code

- `src/main.rs`: single instance, Chromium settings read at startup (GPU, WebRTC, dictionaries), window icon, loads `qml/Main.qml`.
- `src/backend.rs`: the `Backend` object exposed to QML (configuration, recipes, icons, desktop), exchanging JSON.
- `src/config.rs`, `src/recipes.rs`, `src/icons.rs`: configuration file, recipe scripts, trimmed logos.
- `src/i18n.rs`: English translations of the interface, written in French in the QML (`t("…")`).
- `src/dbus.rs`: D-Bus interface and desktop notifications (Linux, with zbus).
- `src/shim.js`, `src/main-world.js`: the `Vigie` object given to recipes, and `window.vigie` in the page.
- `qml/`: the interface (window, sidebar, web views, settings, editor).
- `cpp/app.h`, `src/qtapp.rs`: the `QApplication` (KDE's Qt integration needs widgets) and Qt WebEngine set-up, which cxx-qt-lib does not expose.
- `src/update.rs`: updates (latest release or `main` on GitHub, download, SHA-256, install, restart).
- `outils/release.sh`: release build and spell-checker dictionaries, run in the container by `./vigie-rs`.
- `outils/package.sh`, `.github/workflows/release.yml`: release archive, built and published for each `v*` tag.

## Building and testing (Docker)

```bash
docker build -t vigie-rs-dev .
docker run --rm -v "$PWD":/app -v vigie-rs-cargo:/usr/local/cargo/registry -v vigie-rs-target:/app/target vigie-rs-dev
```

The image is Ubuntu 26.04, with the same Qt (6.10) as the development machine. `test/run.sh` runs:
- the Node test of the shim: badge, CSS, domain restriction, dark mode;
- `cargo test`: configuration (settings unknown to Rust kept), domains, trimmed logos, file URLs, password hash, Chrome user agent, versions and the install of a release archive (checksum, files replaced), and an English translation for every `t("…")` text of the QML;
- `test/e2e.sh`, which runs the app under Xvfb and D-Bus and checks:
  - that the badge comes through from the recipe, the D-Bus counters and `ToggleMute`, a service excluded from the total, the window title, and that a second launch exits;
  - sessions: a cookie set by a service is seen by a service in the same session, and never by an isolated one;
  - notifications: a `Notify` call goes out for the active service, and none for the muted one;
  - windows: a `window.open` after a click opens an app window, with `window.opener`;
  - drag and drop: the first icon dropped onto the second takes its place, and the new order is saved;
  - closing (Ctrl+W): it asks first, Cancel keeps the app, Quit closes it, and it closes at once when the option is off;
  - microphone (Chromium's fake device): a page asks for it, Allow gives it, Deny refuses it;
  - downloads: into the chosen folder, into the default one, and through the "save as" dialog when asking is on;
  - keep in background: closing hides the window without quitting, and a second launch shows it again;
  - Do not disturb is saved, the content of notifications can be hidden, a disabled service is not loaded, a two-factor code from a notification is copied, and the password lock opens only with the right password;
  - last service: the service shown when Vigie closes is the one shown when it starts again;
  - Google sign-in (`*.google.com` served locally): the engine's user agent on every request, then the Chrome one again; with three services sharing a session, signing in to Gmail brings the other two back to their service, signed in;
  - dark theme: a page sees `prefers-color-scheme: dark`, and notification permission is already granted when it loads;
  - reload: Ctrl+R reloads the current service, its service worker kept (WhatsApp recipe); a service with its own shortcut ignores Ctrl+R and reloads with its own.

The tray is not checked there: Qt shows it only when the desktop provides a tray host, which the test session does not.

Compatibility of the 440 recipes. The test runs their code, so it runs without network:

```bash
docker run --rm --network none -v "$PWD":/app:ro vigie-rs-dev node test/recipes_compat.mjs /app/recipes
```

Result as of 5 November 2026: 423 of 440 recipes initialise. 16 of the 17 failures come from the recipes themselves: they read `$` or other page variables, unreachable from the isolated world, or have a bug. The only gap on Vigie's side is `Vigie.ipcRenderer` (tweetdeck).

## Not done yet

`ToggleToTalk`, screen sharing in calls, per-service proxy and HTTP basic auth, `user.js`, workspaces, keyboard reordering, launch at login on Windows and macOS, languages other than French and English. On the recipe side, `setDialogTitle`, `onNotify` and `setAvatarImage` do nothing, and `Vigie.ipcRenderer` does not exist. Windows and macOS builds are not set up, and releases are built for Linux x86_64 only.

## Known limitations

- Tray: shown only when the desktop provides a tray host (KDE Plasma does; GNOME needs the AppIndicator extension). Notifications do not depend on it on Linux.
- In the test container, Chromium's sandbox is disabled (`QTWEBENGINE_DISABLE_SANDBOX`); it stays on in normal use.

## Acknowledgements

Many thanks to the [Ferdium](https://github.com/ferdium) project and its contributors:
- Vigie's features and behaviour are inspired by [Ferdium](https://github.com/ferdium/ferdium-app) (Apache-2.0); Vigie is a separate program, written from scratch in Rust and Qt.
- The `recipes/` catalogue comes from [ferdium-recipes](https://github.com/ferdium/ferdium-recipes), © Ferdium Contributors, under the MIT licence. The recipes were adapted for Vigie: their `Ferdium` API object was renamed `Vigie`, and one recipe under an unclear licence (`buffer`) was left out.

Ferdium itself continues the work of [Ferdi](https://github.com/getferdi/ferdi) and [Franz](https://github.com/meetfranz/franz), whose authors wrote many of these recipes.

## Licences

Vigie's own code is released under the MIT licence, see `LICENSE`.

The `recipes/` catalogue is distributed under the MIT licence, © Ferdium Contributors, from [ferdium-recipes](https://github.com/ferdium/ferdium-recipes). Its copyright notice, in `recipes/LICENSE.md`, and the `LICENSE` files inside individual recipes must stay with the files. Exception: `recipes/weekplan` is under Apache-2.0 (see its `LICENSE`).

The spell-checker dictionaries, converted from the hunspell packages of Ubuntu and shipped in the release archives, keep their own licences (French: MPL-2.0; English: SCOWL and WordNet notices), copied next to them in `dictionaries/*.copyright`.
