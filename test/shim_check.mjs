// Vérifie le shim des recipes sans Qt : node test/shim_check.mjs
// Assemble le script comme recipes::script() dans src/recipes.rs.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const read = p => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');
const files = {
  'webview.js': read('example/recette-test/webview.js'),
  'service.css': read('example/recette-test/service.css'),
};

function run(files, dark, host = 'app.example.org') {
  const script = `const __VIGIE_FILES = ${JSON.stringify(files)};
const __VIGIE_SETTINGS = {"id":"test","domain":"example.org"};
const __VIGIE_DARK = ${dark};
${read('src/shim.js')}
__vigieRun(function (module, exports, require, __dirname) {
${files['webview.js']}
});
`;
  const posted = [];
  const timers = [];
  const byId = new Map();
  const listeners = {};
  const ctx = {
    window: {},
    location: { hostname: host },
    // QWebChannel : l'objet « vigie » de l'app reçoit les messages en JSON.
    qt: { webChannelTransport: {} },
    QWebChannel: function (_transport, ready) {
      ready({ objects: { vigie: { message: m => posted.push(JSON.parse(m)) } } });
    },
    document: {
      head: { append: s => s.id && byId.set(s.id, s) },
      createElement: () => ({ remove() { byId.delete(this.id); } }),
      getElementById: id => byId.get(id) ?? null,
      querySelectorAll: () => ({ length: 3 }),
      addEventListener: (type, fn) => (listeners[type] = fn),
    },
    setInterval: fn => timers.push(fn),
    console,
  };
  const styles = [];
  const append = ctx.document.head.append;
  ctx.document.head.append = s => (styles.push(s.textContent), append(s));
  vm.runInNewContext(script, ctx);
  return { posted, timers, styles, byId, ctx, listeners };
}

const r = run(files, false);
assert.deepEqual(r.styles, [files['service.css']], 'injectCSS via path.join(__dirname, …)');
assert.equal(r.timers.length, 1, 'une seule boucle');
r.timers[0]();
r.timers[0](); // même valeur : pas de second message
assert.deepEqual(r.posted, [{ type: 'badge', direct: 3, indirect: 0 }]);

// Messages du monde de la page (window.vigie) relayés vers l'app.
r.listeners['__vigie-page']({ detail: JSON.stringify({ type: 'badge', direct: 5, indirect: 1 }) });
assert.deepEqual(r.posted.at(-1), { type: 'badge', direct: 5, indirect: 1 });

// Icône du workspace (recipe Slack) envoyée à l'app.
vm.runInContext('Vigie.setAvatarImage("https://example.org/team.png")', r.ctx);
assert.deepEqual(r.posted.at(-1), { type: 'avatar', url: 'https://example.org/team.png' });

// Autre domaine (page de connexion…) : la recipe ne s'exécute pas.
const other = run(files, false, 'accounts.google.com');
assert.deepEqual(other.styles, [], 'pas de recipe hors du domaine du service');
other.timers[0]();
assert.deepEqual(other.posted, [], 'pas de badge hors du domaine du service');

// Mode sombre : darkmode.css de la recipe au démarrage, retiré puis remis par __vigieSetDark.
const css = { ...files, 'darkmode.css': 'body{background:#000}' };
const d = run(css, true);
assert.equal(d.byId.get('vigie-rs-dark')?.textContent, css['darkmode.css']);
vm.runInContext('__vigieSetDark(false)', d.ctx);
assert.ok(!d.byId.has('vigie-rs-dark'), 'darkmode.css retiré');
// handleDarkMode prioritaire ; enableDarkMode demande le mode sombre de Chromium à l'app.
const handled = {
  ...css,
  'webview.js': 'module.exports = F => F.handleDarkMode((on, c) => { globalThis.seen = on; c.injectDarkModeStyle(); c.enableDarkMode(); });',
};
const h = run(handled, true);
assert.equal(h.ctx.seen, true);
assert.ok(h.byId.has('vigie-rs-dark'));
assert.deepEqual(h.posted.at(-1), { type: 'forceDark', on: true });
console.log('ok : shim recipes (badge, CSS, domaine, mode sombre)');
