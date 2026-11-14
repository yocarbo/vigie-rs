#!/bin/sh
# Qt WebEngine de Vigie déjà compilé (outils/qtwebengine.sh), publié sur GitHub dans la pré-release
# « qtwebengine-<version d'Ubuntu>-vaapi-pipewire » : téléchargé dans qtwebengine/ au lieu d'être recompilé, par
# ./vigie-rs et pour les archives de release. Échoue s'il n'y en a pas pour cette version d'Ubuntu.
#   sh outils/qtwebengine-get.sh <version du paquet libqt6webenginecore6>
set -eu
want="$1, VA-API, PipeWire"
# Ni « + », ni « ~ », ni « : » dans un tag git. Les options y sont aussi : une release immuable ne
# rend pas son tag, même supprimée, donc changer d'options (ou rater une publication) en demande un autre.
tag=qtwebengine-$(printf %s "$1" | tr '+~:' '___')-vaapi-pipewire
url=https://github.com/yocarbo/vigie-rs/releases/download/$tag/qtwebengine-linux-x86_64.tar.gz
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/q.tar.gz" "$url" && curl -fsSL -o "$tmp/q.sha256" "$url.sha256" \
  || { echo "Pas de Qt WebEngine de Vigie publié pour $1 ($tag)."; exit 1; }
[ "$(cut -d' ' -f1 "$tmp/q.sha256")" = "$(sha256sum "$tmp/q.tar.gz" | cut -d' ' -f1)" ] \
  || { echo "$tag : empreinte SHA-256 fausse."; exit 1; }
tar xzf "$tmp/q.tar.gz" -C "$tmp"
[ "$(cat "$tmp/qtwebengine/version")" = "$want" ] \
  || { echo "$tag : $(cat "$tmp/qtwebengine/version") au lieu de $want."; exit 1; }
rm -rf qtwebengine
mv "$tmp/qtwebengine" qtwebengine
echo "Qt WebEngine $want téléchargé dans qtwebengine/"
