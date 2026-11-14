# Developing Vigie

Everything a maintainer needs: building from source, how the pieces fit, tests, releases. For using Vigie, see the [README](README.md).

Vigie is written in Rust: Qt 6 (Qt Quick Controls) + Qt WebEngine (Chromium), bound with [cxx-qt](https://github.com/KDAB/cxx-qt). Each service runs in its own web view, with its own session, and a catalogue of 440 recipes (from [ferdium-recipes](https://github.com/ferdium/ferdium-recipes)) reads each service's unread count, applies a dark theme, and so on.

## Running from source

```bash
docker build -t vigie-rs-dev .          # once: the build environment
./vigie-rs                              # your services: ~/.config/vigie-rs/settings.json
VIGIE_CONFIG=example/services.json ./vigie-rs   # two local test services (changes are saved there)
```

`./vigie-rs` builds the release binary in the container (`outils/release.sh`), copies it to `bin/`, converts the French and English hunspell dictionaries for the spell checker into `dictionaries/`, and runs it on the host. It can be run from anywhere, including through a symlink in `~/.local/bin`. Launching it a second time shows the running instance instead of starting another one.

```bash
./vigie-rs install     # binary in /usr/bin, recipes in /usr/share/vigie-rs, menu entry and icon
./vigie-rs uninstall   # removes them; settings and sign-ins stay
```

`PREFIX=/usr/local ./vigie-rs install` installs under another prefix. The administrator password is asked once, only when the prefix is not writable: by `sudo` in a terminal, otherwise by the system's window (`pkexec`). The window's icon is built into the binary, so it shows even when Vigie is not installed.

### Updates

Whether the release Action or `./vigie-rs install` built it, Vigie updates itself from the latest release (`src/update.rs`): it downloads the archive, checks its SHA-256 and replaces its files. When its prefix isn't writable (`/usr`), it runs its own binary again as administrator, `pkexec <binary> --install-archive <archive> <prefix>`, which installs and exits before any window opens. Run from the checkout (`./vigie-rs`) or built by hand, it only reports new versions. To get `main` before it is released: `git pull && ./vigie-rs install`.

### Bundled Qt WebEngine

Chromium decodes H.265 (HEVC) only with the graphics card (VA-API), and Ubuntu builds its Qt WebEngine without VA-API: it uses the system's libvpx, and Qt then turns VA-API off. So Vigie brings its own Qt WebEngine, in `qtwebengine/`: Ubuntu's package, same version and patches, rebuilt with the bundled libvpx and with PipeWire (`webengine_webrtc_pipewire`: on Wayland, Chromium shares the screen only through it, and the desktop's portal asks which screen or window) (`outils/qtwebengine.sh`), without Chromium's sleep inhibition (`power_save_blocker_linux.cc`), and with a seccomp header fix for today's glibc. On OpenGL, which Qt uses, Chromium only decodes with VA-API with the `AcceleratedVideoDecodeLinuxGL` feature, which `src/main.rs` turns on unless GPU acceleration is off.

Built once per Ubuntu version, it is published on GitHub, in the pre-release `qtwebengine-<version of libqt6webenginecore6>-vaapi-pipewire` (`+`, `~` and `:` turned into `_`; the options are in the name because an immutable release's tag can't be reused, even once deleted), as `qtwebengine-linux-x86_64.tar.gz` and its `.sha256`. `outils/qtwebengine-get.sh` downloads it, checks it and puts it in `qtwebengine/`: `./vigie-rs` does so first, and the release Action too, before the tests, which then run with it, and `outils/package.sh` puts it in the archive (`share/vigie-rs/qtwebengine`; updates replace it, links kept). Without one for the image's Ubuntu, the Action only warns, and its archive uses the system's Qt WebEngine.

When none is published, `./vigie-rs` rebuilds it the first time, then whenever Ubuntu updates its own (security fixes) or its options change (`qtwebengine/version`: version and options; an option added after a build reconfigures the existing tree and rebuilds only what changes): several hours, held to 8 GB of memory and 1 job (the inner Chromium ninja included, through `NINJAFLAGS`) so that the machine stays usable, and about 15 GB in the `vigie-rs-qtwebengine` Docker volume. `./vigie-rs install` copies it to `share/vigie-rs/qtwebengine`. The binary looks for its libraries there first (RUNPATH, `build.rs`), and `src/main.rs` then points Qt to its web process, resources and QML module. The rest of Qt still comes from the system, at the same version. If the rebuild fails, Vigie uses the system's Qt WebEngine.

To publish a rebuilt one (a new Ubuntu version, new options), from the repository:

```bash
tar czf qtwebengine-linux-x86_64.tar.gz --owner=0 --group=0 qtwebengine
sha256sum qtwebengine-linux-x86_64.tar.gz >qtwebengine-linux-x86_64.tar.gz.sha256
```

then, on GitHub's Releases page, a new release on the new tag that `outils/qtwebengine-get.sh` expects, both files attached before publishing (release immutability: none can be added afterwards, and the tag is then lost; new options or a missed publication need a new tag in the script), and **Set as a pre-release**: never Vigie's latest version, which `src/update.rs` reads.

## Recipes

A recipe teaches Vigie how to read a service. Each recipe is a folder in `recipes/`:

| File | Purpose |
|---|---|
| `package.json` | service name and default URL (`config.serviceURL`), used by the catalogue |
| `icon.svg` | sidebar and notification icon |
| `webview.js` | the core: a script injected into the service's page, called with the `Vigie` object |
| `service.css`, `darkmode.css` | visual tweaks, and the dark theme when the recipe provides one |
| `webview-unsafe.js` | rare: a script that needs the page's own variables (run in the page's world) |
| `index.js` | settings for the original Electron app, ignored by Vigie |

`webview.js` reads the page every 2 seconds and reports the unread count:

```js
module.exports = Vigie => {
  Vigie.loop(() => Vigie.setBadge(document.querySelectorAll('.unread').length));
};
```

Recipes run in an isolated JavaScript world (Qt WebEngine's `ApplicationWorld`): they see the page's DOM but not its variables, and the site cannot see them. They talk to Vigie through QWebChannel. `injectCSS` sets a `<style>`'s `textContent`, which sites requiring Trusted Types accept. Recipes can break when a site changes its markup; the recipe then needs updating.

Changes from Ferdium's recipes:
- WhatsApp no longer unregisters the page's service workers when it unloads: in Qt WebEngine the unregistration completes on every reload, and WhatsApp then signs out.
- Slack has no `darkmode.css`: Ferdium's, written for Slack's former interface, repainted part of the new one in grey over Slack's own dark theme.
- Google Calendar's reminders (`alert()`) become cards in the page, styled by its own `calendar.css` (the copy linked from a CDN loaded but never applied), with "In 5 min" and "OK".

## Configuration file

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
- Optional: `recipe`, `session`, `dark_mode` (absent: automatic), `user_agent` (absent: the default one), `mute_notifications`, `mute_sound`, `exclude_from_total`, `new_windows` (`auto`, `browser`, `internal`), `disabled`, `hibernate` (unloaded after the delay: `Discarded` lifecycle), `freeze_background` (frozen while hidden, 10 s after loading so that the recipe reads its badge: `Frozen` lifecycle), `nav_bar` (absent: the Appearance setting), `reload_shortcut` (absent: the default one).
- At the top level, next to `theme` and `services`: the settings of the Settings window, for example `quit_without_asking`, `keep_in_background`, `start_minimized`, `show_tray`, `dnd`, `hide_notification_content`, `icon_size`, `language`, `hibernation_minutes`, `download_dir`, `download_ask`, `update_user_agent`, `chrome_major`, `update_check`, `update_checked`, `lock_enabled`, `lock_hash`, `last_service`, `reload_shortcut` (see `qml/Main.qml`, `defaults`). Keys unknown to Rust are kept as they are.
- The old format, a plain array of services, is still read.
- The catalogue is read from `recipes/` next to the configuration file, otherwise from the project's `recipes/` (found by walking up from the binary), or from `share/vigie-rs/recipes` once installed.
- An unreadable configuration file is never overwritten: Vigie starts empty and saves nothing.

Environment variables: `VIGIE_CONFIG` (configuration file), `VIGIE_CONSOLE=1` (JS console of pages and recipes), `VIGIE_OFFLINE=1` (no automatic Chrome version or update check, used by the tests), `QTWEBENGINE_REMOTE_DEBUGGING=9222` (Chromium's DevTools protocol, to inspect a running Vigie).

## Code

- `src/main.rs`: single instance, Chromium settings read at startup (GPU, VA-API, WebRTC, dictionaries, bundled Qt WebEngine), window icon, loads `qml/Main.qml`.
- `src/backend.rs`: the `Backend` object exposed to QML (configuration, recipes, icons, desktop, updates), exchanging JSON.
- `src/config.rs`, `src/recipes.rs`, `src/icons.rs`: configuration file, recipe scripts, trimmed logos.
- `src/i18n.rs`: English translations of the interface, written in French in the QML (`t("…")`).
- `src/dbus.rs`: D-Bus interface, desktop notifications and NetworkManager's "connected" signal (Linux, with zbus).
- `src/shim.js`, `src/main-world.js`: the `Vigie` object given to recipes, and `window.vigie` in the page.
- `qml/`: the interface (window, sidebar, web views, settings, editor, security key window).
- `cpp/app.h`, `src/qtapp.rs`: the `QApplication` (KDE's Qt integration needs widgets) and Qt WebEngine set-up, which cxx-qt-lib does not expose.
- `src/update.rs`: updates (latest release on GitHub, download, SHA-256, install, as administrator if needed, restart).
- `outils/release.sh`: release build and spell-checker dictionaries, run in the container by `./vigie-rs`.
- `outils/qtwebengine.sh`: Vigie's own Qt WebEngine, rebuilt in the container by `./vigie-rs`.
- `outils/package.sh`, `.github/workflows/release.yml`: release archive, built and published for each `v*` tag; `outils/qtwebengine.sh`, `outils/qtwebengine-get.sh`: Vigie's Qt WebEngine, rebuilt or downloaded.

Technical notes:
- Microphone and camera: Qt WebEngine 6.10 never keeps them (`QWebEnginePermission::isPersistent` is false): a grant holds for the page that got it only, unlike Chrome's per-site grant. Slack checks in its main page (`navigator.permissions`) what its call window obtained, saw "prompt", and refused the microphone. So Vigie remembers the answers itself, per service and per device (`microphone`, `camera`: `allow` or `deny`), and grants or denies later requests without asking (a request including a denied device is denied: Qt can't grant part of it). A main-world script (`mediaScript` in `qml/ServiceView.qml`) then makes the service's page see what Chrome would show: `navigator.permissions.query` says `granted` or `denied`, kept up to date with `change` events (Slack listens to them), and an allowed device the page never had is taken for an instant (stopped at once, no question since the answer is remembered) when the page is shown, so that `enumerateDevices` lists it with its id and label: without them, Slack found no microphone to use. A question opens `qml/PermissionWindow.qml`, a small window over the one asking (in the main window, it stayed hidden behind a call window); requests arriving meanwhile from the same service join it, with a box per device when both are asked.
- Screen sharing and clipboard: Qt turns both off by default (`screenCaptureEnabled`, `javascriptCanAccessClipboard`), so `getDisplayMedia` failed with AbortError and "Copy link" buttons did nothing. Both are on in `ServiceView.qml` and `InternalWindow.qml`. A screen share asks in `PermissionWindow.qml` each time, never remembered, as Chrome does; Qt then shares the primary screen (X11). Writing to the clipboard is allowed, reading it still asks, and `askPermission` denies it: pages can't read what Vigie copies there (two-factor codes). On Wayland, Chromium captures the screen through PipeWire only, a build option (`webengine_webrtc_pipewire`) that Ubuntu's Qt WebEngine lacks and Vigie's has (see Bundled Qt WebEngine).
- Security keys: Qt WebEngine signals a WebAuthn request only on a state change (account, PIN, failure), and its timeout is at least 3 minutes. A user script (`qml/Main.qml`) wraps `navigator.credentials.get`/`create` in the page and its frames, reports each request so that the window opens at once, and aborts them (AbortSignal) when the window is cancelled.
- Network: errors 21, 102, 104, 105, 106, 109, 118 and 137 (Qt's internal domain included) reload 4 times (2, 4, 8, 16 s), then once on NetworkManager's `StateChanged` = 70 (connected globally), staggered at random.
- Google sign-in refuses QtWebEngine in disguise ("This browser or app may not be secure"), as Chrome or Firefox, but accepts the engine's own user agent. On every `*.google.com` page and on `accounts.youtube.com`, Vigie presents that one, and the up-to-date Chrome again once a page elsewhere has loaded. Otherwise, sites see an up-to-date Chrome: the "QtWebEngine" mention is removed and the Chrome version comes from [Google's public version API](https://versionhistory.googleapis.com/v1/chrome/platforms/linux/channels/stable/versions), at most once a week.

## D-Bus (Linux)

The `io.github.vigie_rs.Vigie` interface is published on `/io/github/vigie_rs`, under the application's name (`io.github.vigie_rs`), which also makes Vigie single-instance:
- properties `UnreadDirectMessageCount`, `UnreadIndirectMessageCount`, `UnreadServices` and `Muted`;
- methods `ToggleWindow`, `Activate`, `ToggleMute` and `ToggleToTalk`.

```bash
qdbus6 io.github.vigie_rs /io/github/vigie_rs
```

## Building and testing (Docker)

```bash
docker build -t vigie-rs-dev .
docker run --rm -v "$PWD":/app -v vigie-rs-cargo:/usr/local/cargo/registry -v vigie-rs-target:/app/target vigie-rs-dev
```

The image is Ubuntu 26.04, with the same Qt (6.10) as the development machine. `test/run.sh` runs:
- the Node test of the shim: badge, CSS, domain restriction, dark mode;
- `cargo test`: configuration (settings unknown to Rust kept), domains, trimmed logos, file URLs, password hash, Chrome user agent, versions and the install of a release archive (checksum, files replaced), and an English translation for every `t("…")` text of the QML;
- `test/e2e.sh`, which runs the app under Xvfb and D-Bus (window searches retried: xdotool exits on BadWindow when Qt destroys a window it is reading) and checks:
  - that the badge comes through from the recipe, the D-Bus counters and `ToggleMute`, a service excluded from the total, the window title, and that a second launch exits;
  - sessions: a cookie set by a service is seen by a service in the same session, and never by an isolated one;
  - notifications: a `Notify` call goes out for the active service, and none for the muted one;
  - windows: a `window.open` after a click opens an app window, with `window.opener`;
  - drag and drop: the first icon dropped onto the second takes its place, and the new order is saved;
  - closing (Ctrl+W): it asks first, Cancel keeps the app, Quit closes it, and it closes at once when the option is off;
  - microphone (Chromium's fake device): a page asks for it, Vigie's question opens in its own window (`qml/PermissionWindow.qml`), Allow (Enter) gives it, Deny (Escape) refuses it, and a call window opened by the service (a popup, as Slack's) gets its question in front, not behind;
  - clipboard and screen sharing: after a click, a page copies a link (allowed), can't read the clipboard (denied), and shares the screen once allowed, asked again at the next launch;
  - downloads: into the chosen folder, into the default one, and through the "save as" dialog when asking is on;
  - keep in background: closing hides the window without quitting, and a second launch shows it again;
  - Do not disturb is saved, the content of notifications can be hidden, a disabled service is not loaded, a two-factor code from a notification is copied, and the password lock opens only with the right password;
  - last service: the service shown when Vigie closes is the one shown when it starts again;
  - Google sign-in (`*.google.com` served locally): the engine's user agent on every request, then the Chrome one again; with three services sharing a session, signing in to Gmail brings the other two back to their service, signed in;
  - dark theme: a page sees `prefers-color-scheme: dark`, and notification permission is already granted when it loads;
  - reload: Ctrl+R reloads the current service, its service worker kept (WhatsApp recipe); a service with its own shortcut ignores Ctrl+R and reloads with its own;
  - inspector: Inspect, in a page's right-click menu, opens Chromium's developer tools in a window, without crashing Vigie;
  - security key: a WebAuthn request, from the page or a frame, opens the "Security key" window; Escape leaves no request pending;
  - network: a page left on Chromium's error page at startup reloads by itself once its server answers;
  - navigation bar: a service with its own `nav_bar` shows it while the setting says never, and an address typed there opens;
  - Google Calendar reminders: the recipe's reminder cards (in place of `alert()`) are in view and counted in the badge; "In 5 min" takes its own away, closing clears the count, Escape elsewhere leaves it alone;
  - freeze in the background: a service loaded hidden stops running 10 s after loading, and runs again once shown.

The tray is not checked there: Qt shows it only when the desktop provides a tray host, which the test session does not. In the test container, Chromium's sandbox is disabled (`QTWEBENGINE_DISABLE_SANDBOX`); it stays on in normal use.

Compatibility of the 440 recipes. The test runs their code, so it runs without network:

```bash
docker run --rm --network none -v "$PWD":/app:ro vigie-rs-dev node test/recipes_compat.mjs /app/recipes
```

Result as of 5 November 2026: 423 of 440 recipes initialise. 16 of the 17 failures come from the recipes themselves: they read `$` or other page variables, unreachable from the isolated world, or have a bug. The only gap on Vigie's side is `Vigie.ipcRenderer` (tweetdeck).

The README's screenshots come from a demo Vigie (empty home, no accounts, interface in English) run under Xvfb and Openbox in the container: a demo Meet page whose "Join now" opens a demo call in its own Vigie window, and the Calendar reminders on a demo page.

## Publishing a release

Each `vX.Y.Z` tag makes the GitHub Action (`.github/workflows/release.yml`) run the tests, build Vigie in the container and publish `vigie-rs-X.Y.Z-linux-x86_64.tar.gz` with its SHA-256. `main` only takes pull requests: set the new version in `Cargo.toml` (and `Cargo.lock`) on a branch, merge it, then push the tag from `main`:

```bash
git tag v0.4.2 && git push origin v0.4.2   # the tag must match the version in Cargo.toml
```

The Action creates the release itself. Don't create it on GitHub's Releases page: with release immutability on, a release published there without its archive can't take one later, its publication step fails, and its tag can't be reused. A tag whose Action failed stays without a release: publish the next patch version instead.

## Not done yet

`ToggleToTalk`, per-service proxy and HTTP basic auth, `user.js`, workspaces, keyboard reordering, launch at login on Windows and macOS, languages other than French and English. On the recipe side, `setDialogTitle`, `onNotify` and `setAvatarImage` do nothing, and `Vigie.ipcRenderer` does not exist. Windows and macOS builds are not set up, and releases are built for Linux x86_64 only.
