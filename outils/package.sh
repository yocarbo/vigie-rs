#!/bin/sh
# Archive de release (GitHub Action, après outils/release.sh) :
#   sh outils/package.sh <version>  →  dist/vigie-rs-<version>-linux-x86_64.tar.gz et son .sha256
# Elle s'extrait dans un préfixe, que Vigie sait ensuite mettre à jour lui-même :
#   tar xzf vigie-rs-<version>-linux-x86_64.tar.gz --strip-components=1 -C ~/.local
# Le nom et la disposition de l'archive sont ceux qu'attend src/update.rs.
set -eu
app=io.github.vigie_rs
name=vigie-rs-$1-linux-x86_64.tar.gz
root=dist/vigie-rs
rm -rf dist
install -D -m 755 bin/vigie-rs "$root/bin/vigie-rs"
mkdir -p "$root/share/vigie-rs"
cp -r recipes dictionaries "$root/share/vigie-rs/"
install -D -m 644 "assets/$app.desktop" "$root/share/applications/$app.desktop"
install -D -m 644 "assets/$app.svg" "$root/share/icons/hicolor/scalable/apps/$app.svg"
install -D -m 644 LICENSE README.md -t "$root/share/doc/vigie-rs"
tar czf "dist/$name" --owner=0 --group=0 -C dist vigie-rs
rm -rf "$root"
cd dist
sha256sum "$name" >"$name.sha256"
cat "$name.sha256"
