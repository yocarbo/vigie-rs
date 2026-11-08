#!/bin/sh
# Lancé par test/run.sh sous dbus-run-session + xvfb-run (écran 1280×800, sans gestionnaire de
# fenêtres : la fenêtre est en 0,0). Coordonnées des clics : voir les captures de test/captures.sh.
set -eu
log=target/e2e.log
app=
srv=
monitor=
google=
trap 'kill $app $srv $monitor $google 2>/dev/null || true' EXIT
fail() { echo "ÉCHEC : $1"; cat "$log"; exit 1; }
start() { # $1 : configuration (relative au projet)
  VIGIE_CONFIG=$1 target/debug/vigie-rs >"$log" 2>&1 &
  app=$!
  xdotool search --sync --name Vigie >/dev/null
}
stop() {
  kill $app 2>/dev/null || true
  wait $app 2>/dev/null || true
}
wait_log() { # $1 : texte attendu dans le journal
  for _ in $(seq 40); do
    grep -qF "$1" "$log" && return 0
    sleep 0.5
  done
  return 1
}

# Badges : de la recipe (monde isolé, QWebChannel) à l'interface D-Bus io.github.vigie_rs.Vigie.
# Copie de la config : ToggleMute (Ne pas déranger) l'enregistre.
cp example/services.json example/.services.json
start example/.services.json
wait_log '[Test local] badge 3/0' || fail 'pas de badge reçu de la page'
# « Hors total » a bien son badge, mais ne compte ni dans le total ni dans UnreadServices.
wait_log '[Hors total] badge 3/0' || fail 'pas de badge pour « Hors total »'
get() { dbus-send --session --print-reply=literal --dest="$1" "$2" org.freedesktop.DBus.Properties.Get "string:$3" "string:$4"; }
vigie() { get io.github.vigie_rs /io/github/vigie_rs io.github.vigie_rs.Vigie "$1"; }
sleep 1
vigie UnreadDirectMessageCount | grep -q 'uint32 3$' || fail "UnreadDirectMessageCount ≠ 3 : $(vigie UnreadDirectMessageCount)"
vigie UnreadServices | grep -q 'Test local' || fail 'UnreadServices sans « Test local »'
! vigie UnreadServices | grep -q 'Hors total' || fail 'UnreadServices contient « Hors total »'
dbus-send --session --print-reply --dest=io.github.vigie_rs /io/github/vigie_rs io.github.vigie_rs.Vigie.ToggleMute >/dev/null
sleep 0.5
vigie Muted | grep -q 'boolean true' || fail 'ToggleMute sans effet sur Muted'
grep -q '"dnd": true' example/.services.json || fail 'Ne pas déranger non enregistré'
rm -f example/.services.json
xdotool search --name '^\(3\) Test local' >/dev/null || fail 'titre de la fenêtre sans le total (3) ni le service'
# Instance unique : un second lancement affiche la première et s'arrête.
VIGIE_CONFIG=example/services.json timeout 10 target/debug/vigie-rs >/dev/null 2>&1 || fail 'second lancement : pas arrêté'
kill -0 $app 2>/dev/null || fail 'second lancement : la première instance a disparu'
echo 'ok : badge → D-Bus (compteurs, hors total, ToggleMute), titre, instance unique'
stop

# Pages de test servies en local.
node -e "const pages = {
  '/notif': '<script>Notification.requestPermission().then(() => new Notification(\"Bonjour\", { body: \"Corps\" }))</script>',
  '/popup': '<button style=\"position:fixed;inset:0;width:100%;height:100%\" onclick=\"window.open(\'/cible\', \'x\', \'width=500\')\">ouvrir</button>',
  '/cible': '<title>cible</title><script>document.title = window.opener ? \"Popup avec opener\" : \"Popup sans opener\"</script>',
  '/micro': '<button style=\"position:fixed;inset:0;width:100%;height:100%\" onclick=\"navigator.mediaDevices.getUserMedia({ audio: true }).then(() => console.log(\'MICRO ok\'), e => console.log(\'MICRO \' + e.name))\">micro</button>',
  '/telecharger': '<a href=\"/doc.txt\" download style=\"position:fixed;inset:0;display:block\">télécharger</a>',
  '/code': '<script>Notification.requestPermission().then(() => new Notification(\"Messages\", { body: \"Votre code de vérification : 482913\" }))</script>',
  '/retour': '<script>console.log(\"UA retour \" + navigator.userAgent); setTimeout(() => location.href = \"/apres\", 1000)</script>',
  '/apres': '<script>console.log(\"UA apres \" + navigator.userAgent)</script>',
  '/schema': '<script>console.log(\"SCHEMA \" + matchMedia(\"(prefers-color-scheme: dark)\").matches + \" NOTIF \" + Notification.permission)</script>',
  '/recharge': '<script>localStorage.n = +(localStorage.n || 0) + 1; navigator.serviceWorker.getRegistrations().then(r => { console.log(\"CHARGE \" + localStorage.n + \" SW \" + r.length); return navigator.serviceWorker.register(\"/sw.js\") })</script>',
};
require('http').createServer((q, r) => {
  if (q.url === '/connexion') {
    r.writeHead(302, { location: 'https://accounts.google.com/signin?retour' });
    return r.end();
  }
  if (q.url === '/sw.js') {
    r.setHeader('content-type', 'text/javascript');
    return r.end('');
  }
  if (q.url === '/doc.txt') {
    r.setHeader('content-type', 'text/plain');
    return r.end('contenu');
  }
  r.setHeader('content-type', 'text/html; charset=utf-8');
  r.end(pages[q.url] ?? '<!doctype html><title>t</title>ok');
}).listen(8123)" &
srv=$!
sleep 0.5

# Sessions : « Pose » écrit un cookie ; « Partage » (même session) doit le voir, « Isole » non.
start example/sessions.json
wait_log '[Partage] badge 1/0' || fail 'session partagée : cookie invisible pour « Partage »'
sleep 3 # laisse à « Isole » le temps de voir un cookie qu'il ne devrait pas voir
grep -qF '[Isole] badge 0/0' "$log" || fail 'service isolé : pas de badge reçu'
! grep -qF '[Isole] badge 1/0' "$log" || fail 'service isolé : il voit le cookie d’une autre session'
echo 'ok : sessions (partage entre services, isolation par défaut)'
stop

# Notifications : envoyées au bureau (Notify) pour « Notif oui », jamais pour « Notif non » (coupé).
mon=target/notify.log
dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" >"$mon" 2>&1 &
monitor=$!
start example/notifications.json
for _ in $(seq 40); do
  grep -qF 'Notif oui : Bonjour' "$mon" && break
  sleep 0.5
done
sleep 3
grep -qF 'Notif oui : Bonjour' "$mon" || { cat "$mon"; fail 'notification du service actif non envoyée'; }
grep -qF 'string "Corps"' "$mon" || fail 'corps de la notification absent'
! grep -qF 'Notif non' "$mon" || fail 'notification envoyée pour un service coupé'
echo 'ok : notifications (envoyées au bureau, coupées par service)'
stop
kill $monitor 2>/dev/null || true

# Nouvelles fenêtres (automatique) : un window.open après un clic s'ouvre dans l'app, avec window.opener.
start example/fenetres.json
sleep 3
xdotool mousemove 600 400 click 1
found=
for _ in $(seq 20); do
  found=$(xdotool search --name 'Popup (avec|sans) opener' getwindowname %@ 2>/dev/null || true)
  [ -n "$found" ] && break
  sleep 0.5
done
# Qt ajoute « — Vigie » au titre des fenêtres secondaires.
[ "${found%% — Vigie}" = 'Popup avec opener' ] || fail "fenêtre interne : « ${found:-aucune} »"
echo 'ok : fenêtre interne pour window.open, window.opener conservé'
stop

# Glisser-déposer : la 1re icône déposée sur la 2e prend sa place, et l'ordre est enregistré.
cfg=example/.drag.json
cp example/services.json "$cfg"
start "$cfg"
sleep 3
xdotool mousemove 32 31 mousedown 1 sleep 0.3 mousemove 32 45 sleep 0.2 mousemove 32 65 \
  sleep 0.2 mousemove 32 87 sleep 0.4 mouseup 1
sleep 1
order=$(grep -o '"id": "[^"]*"' "$cfg" | tr '\n' ' ')
rm -f "$cfg"
[ "$order" = '"id": "hors-total" "id": "test" ' ] || fail "ordre après glisser-déposer : ${order:-inchangé}"
echo 'ok : glisser-déposer des services (ordre enregistré)'
stop

# Fermeture (Ctrl+W, comme la croix) : confirmation, Annuler garde l'app, Quitter la ferme ;
# fermeture directe quand l'option est désactivée.
quits() { # vrai si l'app se termine d'elle-même en moins de 5 s
  ( sleep 5; kill $app 2>/dev/null ) & watchdog=$!
  st=0; wait $app || st=$?
  kill $watchdog 2>/dev/null || true
  [ $st -ne 143 ]
}
close_window() { xdotool mousemove 600 400 click 1 key ctrl+w; sleep 1.5; }
start example/services.json
sleep 2
close_window
kill -0 $app 2>/dev/null || fail 'fermeture : l’app a quitté sans confirmation'
xdotool mousemove 849 432 click 1 # Annuler
sleep 1
kill -0 $app 2>/dev/null || fail 'Annuler a fermé l’app'
close_window
xdotool mousemove 763 432 click 1 # Quitter
quits || fail 'Quitter n’a pas fermé l’app'
printf '{"quit_without_asking": true}\n' >example/.quit.json
start example/.quit.json
sleep 2
close_window
quits || fail 'option désactivée : la fermeture n’a pas quitté l’app'
rm -f example/.quit.json
echo 'ok : fermeture (confirmation, Annuler, Quitter, option désactivée)'

# Micro (faux périphérique de Chromium) : la page le demande, l'app pose la question.
micro() { # $1 : abscisse du bouton du dialogue ; affiche la réponse de la page
  export VIGIE_CONSOLE=1 QTWEBENGINE_CHROMIUM_FLAGS=--use-fake-device-for-media-stream
  start example/micro.json
  sleep 3
  xdotool mousemove 600 400 click 1
  sleep 1.5
  xdotool mousemove "$1" 418 click 1
  sleep 1.5
  stop
  grep -o 'MICRO [A-Za-z]*' "$log" | head -1
}
got=$(micro 605)
[ "$got" = 'MICRO ok' ] || fail "micro : Autoriser n’a pas donné le micro (${got:-pas de réponse})"
got=$(micro 691)
# Qt WebEngine signale le refus par AbortError (Chromium seul : NotAllowedError).
case "$got" in
  'MICRO NotAllowedError' | 'MICRO AbortError') ;;
  *) fail "micro : Refuser n’a pas refusé le micro (${got:-pas de réponse})" ;;
esac
echo 'ok : micro (demande d’autorisation, Autoriser, Refuser)'

# Téléchargements : dans le dossier choisi ; sans dossier, dans celui du système (ici ~/Downloads,
# le conteneur n'ayant ni dossier XDG ni ~/Téléchargements) ; sur demande, Vigie demande où
# enregistrer (bouton Save du dialogue : nom et dossier proposés).
dl=$PWD/target/dl
rm -rf "$dl" && mkdir -p "$dl"
printf '{"download_dir": "%s", "services": [{"id": "dl", "name": "Telechargement", "url": "http://127.0.0.1:8123/telecharger"}]}\n' "$dl" >example/.dl.json
start example/.dl.json
sleep 3
xdotool mousemove 600 400 click 1
for _ in $(seq 20); do [ -f "$dl/doc.txt" ] && break; sleep 0.5; done
[ -f "$dl/doc.txt" ] || fail 'téléchargement : fichier absent du dossier choisi'
stop
printf '{"services": [{"id": "dl", "name": "Telechargement", "url": "http://127.0.0.1:8123/telecharger"}]}\n' >example/.dl.json
rm -f "$HOME/Downloads/doc.txt"
start example/.dl.json
sleep 3
xdotool mousemove 600 400 click 1
for _ in $(seq 20); do [ -f "$HOME/Downloads/doc.txt" ] && break; sleep 0.5; done
[ -f "$HOME/Downloads/doc.txt" ] || fail 'téléchargement : fichier absent du dossier par défaut'
stop
rm -f "$HOME/Downloads/doc.txt"
printf '{"download_ask": true, "services": [{"id": "dl", "name": "Telechargement", "url": "http://127.0.0.1:8123/telecharger"}]}\n' >example/.dl.json
start example/.dl.json
sleep 3
xdotool mousemove 600 400 click 1
sleep 2
xdotool mousemove 802 576 click 1
for _ in $(seq 20); do [ -f "$HOME/Downloads/doc.txt" ] && break; sleep 0.5; done
[ -f "$HOME/Downloads/doc.txt" ] || fail 'téléchargement : rien d’enregistré après la demande d’emplacement'
stop
rm -f example/.dl.json "$HOME/Downloads/doc.txt"
echo 'ok : téléchargements (dossier choisi, dossier par défaut, emplacement demandé)'

# Arrière-plan : fermer la fenêtre la cache sans quitter ; un second lancement la réaffiche.
printf '{"keep_in_background": true, "services": [{"id": "bg", "name": "Fond", "url": "about:blank"}]}\n' >example/.bg.json
start example/.bg.json
sleep 2
close_window
kill -0 $app 2>/dev/null || fail 'arrière-plan : l’app a quitté'
[ -z "$(xdotool search --onlyvisible --name '^Fond' 2>/dev/null)" ] || fail 'arrière-plan : la fenêtre est restée affichée'
VIGIE_CONFIG=example/.bg.json timeout 10 target/debug/vigie-rs >/dev/null 2>&1 || true
sleep 1
[ -n "$(xdotool search --onlyvisible --name '^Fond' 2>/dev/null)" ] || fail 'arrière-plan : la fenêtre n’est pas revenue'
stop
rm -f example/.bg.json
echo 'ok : arrière-plan (fermer cache la fenêtre, un second lancement la réaffiche)'

# Contenu des notifications masqué : seulement le nom du service.
printf '{"hide_notification_content": true, "services": [{"id": "n", "name": "Discret", "url": "http://127.0.0.1:8123/notif"}]}\n' >example/.discret.json
dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" >"$mon" 2>&1 &
monitor=$!
start example/.discret.json
for _ in $(seq 40); do
  grep -qF 'string "Discret"' "$mon" && break
  sleep 0.5
done
grep -qF 'string "Discret"' "$mon" || fail 'contenu masqué : pas de notification'
! grep -qF 'Bonjour' "$mon" || fail 'contenu masqué : le titre de la page est visible'
grep -qE 'string "(Nouveau message|New message)"' "$mon" || fail 'contenu masqué : corps inattendu'
stop
kill $monitor 2>/dev/null || true
rm -f example/.discret.json
echo 'ok : contenu des notifications masqué'

# Service désactivé : gardé dans la liste, jamais chargé (pas de badge).
cat >example/.desactive.json <<'JSON'
{"services": [
  {"id": "actif", "name": "Actif", "url": "data:text/html,<p class=unread>1</p>", "recipe": "recette-test"},
  {"id": "eteint", "name": "Eteint", "url": "data:text/html,<p class=unread>1</p>", "recipe": "recette-test", "disabled": true}
]}
JSON
start example/.desactive.json
wait_log '[Actif] badge 1/0' || fail 'service actif : pas de badge'
sleep 2
! grep -qF '[Eteint] badge' "$log" || fail 'service désactivé : il a été chargé'
stop
rm -f example/.desactive.json
echo 'ok : service désactivé (non chargé)'

# Code à deux facteurs : copié depuis une notification qui contient un mot-clé.
printf '{"auto_copy_2fa": true, "services": [{"id": "sms", "name": "SMS", "url": "http://127.0.0.1:8123/code"}]}\n' >example/.code.json
start example/.code.json
wait_log 'code à deux facteurs copié' || fail 'code à deux facteurs : non copié'
stop
rm -f example/.code.json
echo 'ok : code à deux facteurs copié'

# Verrouillage (mot de passe « secret ») : verrouillé au démarrage, un mauvais mot de passe ne
# déverrouille pas, le bon si.
cat >example/.verrou.json <<'JSON'
{"lock_enabled": true, "lock_hash": "$argon2id$v=19$m=19456,t=2,p=1$9MgEUKTby8WyDqHLUqa6EA$VDeXzSQT8EZ1iQNh7brGbsyR/WbiAwpfyPwkBTaaIm4",
 "services": [{"id": "v", "name": "Verrou", "url": "about:blank"}]}
JSON
start example/.verrou.json
wait_log 'qml: verrouillé' || fail 'verrouillage : pas verrouillé au démarrage'
sleep 1
xdotool type --delay 50 'mauvais'
xdotool key Return
sleep 1.5
! grep -qF 'déverrouillé' "$log" || fail 'verrouillage : un mauvais mot de passe a déverrouillé'
xdotool type --delay 50 'secret'
xdotool key Return
wait_log 'déverrouillé' || fail 'verrouillage : le bon mot de passe n’a pas déverrouillé'
stop
rm -f example/.verrou.json
echo 'ok : verrouillage par mot de passe'

# Dernier service : on affiche le 2e, et Vigie le rouvre au lancement suivant.
cp example/services.json example/.dernier.json
start example/.dernier.json
sleep 3
xdotool mousemove 32 87 click 1
sleep 1
stop
grep -q '"last_service": "hors-total"' example/.dernier.json || fail 'dernier service non enregistré'
start example/.dernier.json
sleep 3
xdotool search --name 'Hors total' >/dev/null || fail 'Vigie ne rouvre pas le dernier service affiché'
stop
rm -f example/.dernier.json
echo 'ok : réouverture sur le dernier service affiché'

# Connexion Google (servie ici, certificat autosigné) : user-agent du moteur (« QtWebEngine/ ») sur
# tout *.google.com, puis celui de Chrome à nouveau une fois revenu au service. Trois services d'une
# même session, déconnectés, redirigés vers la page de connexion : Gmail s'y connecte (cookie SID),
# Messages et Agenda retournent alors à leur service, connectés. Chaque requête est notée.
openssl req -x509 -newkey rsa:2048 -nodes -keyout target/google.key -out target/google.crt -days 1 \
  -subj /CN=accounts.google.com 2>/dev/null
echo '127.0.0.1 accounts.google.com mail.google.com messages.google.com calendar.google.com' >>/etc/hosts
glog=target/google.log
: >"$glog"
node -e "const fs = require('fs');
require('https').createServer({ key: fs.readFileSync('target/google.key'), cert: fs.readFileSync('target/google.crt') }, (q, r) => {
  const host = q.headers.host, signedIn = /SID=1/.test(q.headers.cookie || '');
  fs.appendFileSync('$glog', host + q.url + (signedIn ? ' connecté' : '') + ' ' + q.headers['user-agent'] + '\n');
  r.setHeader('content-type', 'text/html; charset=utf-8');
  if (host === 'accounts.google.com')
    return r.end('<script>setTimeout(() => {' +
      'if (location.search === \"?retour\") location.href = \"http://localhost:8123/retour\";' +
      'if (location.search === \"?mail\") { document.cookie = \"SID=1; domain=.google.com; path=/; secure\"; location.href = \"https://mail.google.com/mail/\" }' +
      '}, location.search === \"?mail\" ? 3000 : 1000)</script>');
  if (signedIn)
    return r.end('connecté');
  r.writeHead(302, { location: 'https://accounts.google.com/signin?' + host.split('.')[0] });
  r.end();
}).listen(443)" &
google=$!
export VIGIE_CONSOLE=1 QTWEBENGINE_CHROMIUM_FLAGS=--ignore-certificate-errors
start example/google.json
wait_log 'console : UA apres' || fail 'connexion Google : pas de retour au service'
for _ in $(seq 20); do
  grep -q '^calendar.google.com/u/0/ connecté' "$glog" && grep -q '^messages.google.com/web connecté' "$glog" && break
  sleep 0.5
done
sleep 1
stop
cat "$glog" >>"$log"
! grep -v 'QtWebEngine/' "$glog" || fail 'connexion Google : requête envoyée à Google sous un autre user-agent que celui du moteur'
grep 'console : UA apres' "$log" | grep 'Chrome/' | grep -qv 'QtWebEngine/' || fail 'connexion Google : user-agent de Chrome non rétabli'
[ "$(grep -c 'signin?retour' "$glog")" -eq 1 ] || fail 'connexion Google : page rechargée en boucle'
grep -q '^mail.google.com/mail/ connecté' "$glog" || fail 'connexion Google : Gmail non connecté'
grep -q '^calendar.google.com/u/0/ connecté' "$glog" || fail 'connexion Google : Agenda pas revenu au service une fois Gmail connecté'
grep -q '^messages.google.com/web connecté' "$glog" || fail 'connexion Google : Messages pas revenu au service une fois Gmail connecté'
[ "$(grep -c 'signin?calendar' "$glog")" -eq 1 ] || fail 'connexion Google : page de connexion rechargée en boucle'
echo 'ok : connexion Google (user-agent du moteur, session partagée connectée partout, puis Chrome)'

# Thème sombre : les pages voient prefers-color-scheme: dark (Slack, WhatsApp… suivent le leur).
# Notifications déjà accordées au chargement, sans demande (pas de bandeau de Slack).
printf '{ "theme": "dark", "services": [ { "id": "schema", "name": "Schéma", "url": "http://localhost:8123/schema" } ] }' >example/.sombre.json
start example/.sombre.json
wait_log 'console : SCHEMA' || fail 'thème sombre : page non chargée'
stop
rm -f example/.sombre.json
grep -q 'console : SCHEMA true' "$log" || fail 'thème sombre : la page ne voit pas prefers-color-scheme: dark'
grep -q 'console : SCHEMA .* NOTIF granted' "$log" || fail 'notifications non accordées d’avance'
echo 'ok : thème sombre transmis aux pages (prefers-color-scheme), notifications accordées d’avance'

# Rechargement : Ctrl+R recharge le service affiché, sans désinscrire son service worker (recipe
# WhatsApp : il se déconnectait) ; un service qui a son propre raccourci ignore Ctrl+R.
cat >example/.recharge.json <<'JSON'
{"services": [
  {"id": "recharge", "name": "Recharge", "url": "http://localhost:8123/recharge", "recipe": "whatsapp"},
  {"id": "touche", "name": "Touche", "url": "http://localhost:8123/recharge", "reload_shortcut": "Ctrl+Shift+R"}
]}
JSON
start example/.recharge.json
wait_log '[Recharge] console : CHARGE 1 SW 0' || fail 'rechargement : page non chargée'
xdotool mousemove 600 400 click 1 key ctrl+r
wait_log '[Recharge] console : CHARGE 2' || fail 'rechargement : Ctrl+R sans effet'
grep -qF '[Recharge] console : CHARGE 2 SW 1' "$log" || fail 'rechargement : service worker désinscrit'
xdotool mousemove 32 87 click 1
wait_log '[Touche] console : CHARGE 1' || fail 'raccourci du service : page non chargée'
sleep 1
xdotool mousemove 600 400 click 1 key ctrl+r
sleep 3
! grep -qF '[Touche] console : CHARGE 2' "$log" || fail 'raccourci du service : Ctrl+R l’a rechargé'
xdotool key ctrl+shift+r
wait_log '[Touche] console : CHARGE 2' || fail 'raccourci du service : Ctrl+Shift+R sans effet'
stop
rm -f example/.recharge.json
echo 'ok : rechargement (Ctrl+R, service worker gardé, raccourci propre au service)'

# Inspecteur : clic droit, « Inspecter » ; les outils de Chromium s'ouvrent dans une fenêtre, sans
# planter Vigie (posé dès la création de la fenêtre, `inspectedView` le faisait planter).
printf '{"services": [{"id": "insp", "name": "Inspection", "url": "http://localhost:8123/inspecter"}]}\n' >example/.inspecter.json
start example/.inspecter.json
sleep 3
xdotool mousemove 600 400 click 3
sleep 1
xdotool mousemove 628 494 click 1 # Inspecter, dernière entrée du menu
found=
for _ in $(seq 20); do
  found=$(xdotool search --name '^(Inspecteur|Inspector) — Inspection' 2>/dev/null || true)
  [ -n "$found" ] && break
  sleep 0.5
done
[ -n "$found" ] || fail 'inspecteur : fenêtre non ouverte'
sleep 2
kill -0 $app 2>/dev/null || fail 'inspecteur : Vigie a planté'
stop
rm -f example/.inspecter.json
echo 'ok : inspecteur (outils de développement dans une fenêtre)'
