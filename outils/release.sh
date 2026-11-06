#!/bin/sh
# Dans le conteneur (appelé par ./vigie-rs) : compile la version release dans bin/, et convertit les
# dictionnaires hunspell (français, anglais) au format de Qt WebEngine dans dictionaries/.
#   sh outils/release.sh <uid> <gid>
set -eu
owner="-o ${1:-0} -g ${2:-0}"
cargo build -q --release
install -D -m 755 $owner target/release/vigie-rs bin/vigie-rs
convert=/usr/lib/qt6/libexec/qwebengine_convert_dict
for pair in fr_FR:fr-FR en_US:en-US; do
  src=/usr/share/hunspell/${pair%%:*}.dic
  dst=dictionaries/${pair##*:}.bdic
  # Licence du dictionnaire (MPL-2.0 pour le français), distribuée avec lui dans les releases.
  pkg=$(dpkg -S "$(readlink -f "$src")" 2>/dev/null | cut -d: -f1) || true
  copyright=/usr/share/doc/$pkg/copyright
  [ -n "$pkg" ] && [ -f "$copyright" ] && install -D -m 644 $owner "$copyright" "dictionaries/${pair##*:}.copyright"
  [ -f "$dst" ] || [ ! -f "$src" ] && continue
  "$convert" "$src" "target/${pair##*:}.bdic" >/dev/null
  install -D -m 644 $owner "target/${pair##*:}.bdic" "$dst"
done
