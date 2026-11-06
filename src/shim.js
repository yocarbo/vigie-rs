// Monde isolé (ApplicationWorld) : l'objet `Vigie` passé aux recipes. Rust préfixe ce fichier avec :
//   const __VIGIE_FILES = { "<nom de fichier>": "<contenu>" };  // *.css et *.js de la recipe
//   const __VIGIE_SETTINGS = { ...service, domain, isDarkModeEnabled };
//   const __VIGIE_DARK = true | false;
// Les messages partent vers l'app par QWebChannel (objet « vigie »), en attente tant qu'il n'est pas prêt.
let __send = null;
const __queue = [];
const __post = m => {
  const s = JSON.stringify(m);
  if (__send) __send(s);
  else __queue.push(s);
};
const __file = p => __VIGIE_FILES[String(p).split('/').pop()];
const __safeParseInt = t => {
  if (t === undefined || t === null) return 0;
  const n = Number.parseInt(t.toString(), 10);
  return Math.max(Number.isNaN(n) ? 0 : n, 0);
};
const __css = (text, id) => {
  const s = document.createElement('style');
  s.textContent = text; // pas innerHTML : bloqué sur les sites qui exigent Trusted Types
  if (id) s.id = id;
  (document.head || document.documentElement).append(s);
  return s;
};

// Mode sombre : handleDarkMode de la recipe, sinon son darkmode.css. Sans thème de recipe, l'app
// active le mode sombre automatique de Chromium (forceDarkMode).
let __darkHandler = null;
const __toggleCss = (id, text, on) => {
  const s = document.getElementById(id);
  if (on && !s && text) __css(text, id);
  if (!on && s) s.remove();
};
const __darkConfig = {
  injectDarkModeStyle: () => __toggleCss('vigie-rs-dark', __VIGIE_FILES['darkmode.css'], true),
  removeDarkModeStyle: () => __toggleCss('vigie-rs-dark', '', false),
  isDarkModeStyleInjected: () => !!document.getElementById('vigie-rs-dark'),
  enableDarkMode: () => __post({ type: 'forceDark', on: true }),
  disableDarkMode: () => __post({ type: 'forceDark', on: false }),
};
// Appelée par l'app (runJavaScript dans ce monde) quand le thème change.
function __vigieSetDark(on) {
  if (__darkHandler) return __darkHandler(on, __darkConfig);
  return __toggleCss('vigie-rs-dark', __VIGIE_FILES['darkmode.css'], on);
}

// La boucle de la recipe tourne toutes les 2 s.
let __loop = () => {};
setInterval(() => {
  try {
    __loop();
  } catch (e) {
    console.error('recipe loop', e);
  }
}, 2000);

let __lastBadge = '';
const Vigie = {
  loop(fn) {
    __loop = fn;
  },
  setBadge(direct = 0, indirect = 0) {
    const m = { type: 'badge', direct: __safeParseInt(direct), indirect: __safeParseInt(indirect) };
    const key = JSON.stringify(m);
    if (key !== __lastBadge) {
      __lastBadge = key;
      __post(m);
    }
  },
  safeParseInt: __safeParseInt,
  injectCSS(...files) {
    files.map(__file).filter(Boolean).forEach(__css);
  },
  injectJSUnsafe(...files) {
    files.map(__file).filter(Boolean).forEach(code => __post({ type: 'js', code }));
  },
  openNewWindow(url) {
    __post({ type: 'open', url: String(url) });
  },
  isImage(link) {
    if (link === undefined) return false;
    const { role } = link.dataset;
    if (role !== undefined) return role === 'img';
    return /\.(jpg|jpeg|png|webp|avif|gif|svg)($|\?|:)/.test(link.getAttribute('href').split(/[#?]/)[0]);
  },
  async releaseServiceWorkers() {
    try {
      for (const r of await navigator.serviceWorker.getRegistrations()) r.unregister();
    } catch (e) {
      console.debug(e);
    }
  },
  clearStorageData() {
    __post({ type: 'clear' });
  },
  handleDarkMode(fn) {
    __darkHandler = fn;
  },
  // Icône du service dans la barre (celle du workspace Slack…), à la place du logo de la recipe.
  setAvatarImage(url) {
    if (url) __post({ type: 'avatar', url: String(url) });
  },
  // ponytail: no-ops, à brancher quand une recipe utilisée en a besoin.
  setDialogTitle() {},
  onNotify() {},
  toggleToTalk() {},
};

// Les recipes compilées font `require('path')` puis `path.join(__dirname, 'service.css')`.
const __require = name => {
  if (name === 'path') {
    return { join: (...p) => p.join('/'), basename: p => String(p).split('/').pop() };
  }
  throw new Error(`vigie-rs : require('${name}') non supporté`);
};

// La recipe ne vise que la page du service : ni les fenêtres qu'il ouvre, ni les autres domaines
// (page de connexion Google…), sinon leurs badges (0) écraseraient ceux du service.
const __forService = () => {
  const d = __VIGIE_SETTINGS.domain;
  const h = location.hostname;
  return !window.opener && (!d || h === d || h.endsWith(`.${d}`));
};

function __vigieRun(factory) {
  if (!__forService()) return;
  if (typeof QWebChannel === 'function' && typeof qt === 'object') {
    new QWebChannel(qt.webChannelTransport, channel => {
      const bridge = channel.objects.vigie;
      __send = s => bridge.message(s);
      __queue.splice(0).forEach(__send);
    });
  }
  // Messages du monde de la page (window.vigie, scripts injectJSUnsafe) : relayés vers l'app.
  document.addEventListener('__vigie-page', e => {
    try {
      const m = JSON.parse(e.detail);
      if (m.type === 'badge') Vigie.setBadge(m.direct, m.indirect);
      else if (m.type === 'open') Vigie.openNewWindow(m.url);
    } catch (err) {
      console.debug(err);
    }
  });
  const module = { exports: {} };
  try {
    factory(module, module.exports, __require, '/recipe');
    const init = module.exports.default || module.exports;
    if (typeof init === 'function') init(Vigie, __VIGIE_SETTINGS);
  } catch (e) {
    console.error('Recipe initialization failed', e);
  }
  if (__VIGIE_FILES['user.css']) __css(__VIGIE_FILES['user.css']);
  if (__VIGIE_DARK) {
    try {
      __vigieSetDark(true);
    } catch (e) {
      console.error('Recipe dark mode failed', e);
    }
  }
}
