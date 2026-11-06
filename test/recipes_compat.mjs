// Compatibilité des recipes du catalogue avec src/shim.js. Exécute du code tiers :
// à lancer dans le conteneur sans réseau (voir README) :
//   node test/recipes_compat.mjs /recipes/recipes
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import vm from 'node:vm';

const root = process.argv[2];
const shim = readFileSync(new URL('../src/shim.js', import.meta.url), 'utf8');

// DOM factice permissif : toute propriété ou tout appel renvoie le même objet.
const any = new Proxy(function () {}, {
  get: (_, k) =>
    k === Symbol.toPrimitive ? () => 0
    : k === Symbol.iterator ? function* () {}
    : k === 'then' ? undefined
    : k === 'length' ? 0
    : any,
  apply: () => any,
  construct: () => any,
  set: () => true,
});

function run(files) {
  const errors = [];
  const timers = [];
  const ctx = {
    webkit: { messageHandlers: { vigie: { postMessage() {} } } },
    document: any, navigator: any, localStorage: any, location: new URL('https://example.com/'),
    indexedDB: { databases: async () => [], open: any },
    MutationObserver: any, Notification: any, Event: any, CustomEvent: any, URL, JSON,
    addEventListener: any, removeEventListener: any, dispatchEvent: any, getComputedStyle: any,
    setInterval: fn => timers.push(fn), setTimeout: () => 0, clearInterval() {}, clearTimeout() {},
    console: { log() {}, info() {}, warn() {}, debug() {}, error: (...a) => errors.push(a.at(-1)) },
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  const script = `const __VIGIE_FILES = ${JSON.stringify(files)};
const __VIGIE_SETTINGS = {};
const __VIGIE_DARK = false;
${shim}
__vigieRun(function (module, exports, require, __dirname) {
${files['webview.js']}
});
Vigie`;
  try {
    const api = vm.runInContext(script, ctx, { timeout: 2000 });
    timers.forEach(t => t()); // un tour de boucle de recipe
    return { api, errors };
  } catch (e) {
    return { api: null, errors: [...errors, e] };
  }
}

const recipes = readdirSync(root).filter(d => existsSync(join(root, d, 'webview.js')));
const use = new Map(); // méthode → recipes
const requires = new Map();
const failures = [];
let api;
for (const name of recipes) {
  const dir = join(root, name);
  const files = Object.fromEntries(
    readdirSync(dir).filter(f => /\.(css|js)$/.test(f)).map(f => [f, readFileSync(join(dir, f), 'utf8')]),
  );
  const src = files['webview.js'];
  const param = /module\.exports\s*=\s*(?:async\s*)?\(?\s*(\w+)/.exec(src)?.[1] ?? 'Vigie';
  for (const [, m] of src.matchAll(new RegExp(`\\b${param}\\.(\\w+)`, 'g'))) {
    use.set(m, (use.get(m) ?? new Set()).add(name));
  }
  for (const [, r] of src.matchAll(/require\(\s*['"]([^'"]+)['"]\s*\)/g)) {
    requires.set(r, (requires.get(r) ?? new Set()).add(name));
  }
  const res = run(files);
  api ??= res.api;
  if (res.errors.length) failures.push([name, String(res.errors[0]?.message ?? res.errors[0])]);
}

const kind = m => {
  const f = api?.[m];
  if (typeof f !== 'function') return 'ABSENT';
  return /\{\s*\}$|=>\s*false$/.test(f.toString()) ? 'no-op' : 'ok';
};
const rows = [...use].map(([m, s]) => [m, s.size, kind(m)]).sort((a, b) => b[1] - a[1]);
console.log(`${recipes.length} recipes avec webview.js\n\n== API Vigie utilisée (méthode, nb recipes, état) ==`);
for (const r of rows) console.log(r.join('\t'));
console.log('\n== require() ==');
for (const [r, s] of requires) console.log(`${r}\t${s.size}\t${r === 'path' ? 'ok' : 'ABSENT'}`);
const fail = new Map();
for (const [n, msg] of failures) fail.set(msg, [...(fail.get(msg) ?? []), n]);
console.log(`\n== Échecs à l'initialisation ou au 1er tour de boucle : ${failures.length}/${recipes.length} ==`);
for (const [msg, names] of [...fail].sort((a, b) => b[1].length - a[1].length)) {
  console.log(`${names.length}\t${msg.slice(0, 110)}\t${names.slice(0, 6).join(', ')}${names.length > 6 ? ', …' : ''}`);
}
