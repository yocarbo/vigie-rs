#!/bin/sh
# Tests dans le conteneur : shim JS, tests Rust, compilation, puis lancement sous Xvfb (test/e2e.sh).
set -eu

node test/shim_check.mjs
# Sortie complète seulement en cas d'échec (le résultat compte pour la GitHub Action).
out=$(cargo test -q 2>&1) || { echo "$out"; exit 1; }
echo "$out" | grep -E "test result"
cargo build -q

# Le bac à sable de Chromium ne démarre pas dans un conteneur non privilégié : test seulement.
export QTWEBENGINE_DISABLE_SANDBOX=1
# Pas de requête réseau pendant les tests (version de Chrome du user-agent).
export VIGIE_OFFLINE=1
exec dbus-run-session -- xvfb-run -a -s '-screen 0 1280x800x24' sh test/e2e.sh
