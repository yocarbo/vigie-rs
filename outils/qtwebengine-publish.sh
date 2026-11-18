#!/bin/sh
# Qt WebEngine de Vigie (qtwebengine/, outils/qtwebengine.sh) mis dans dist/ (archive et empreinte),
# puis publié dans la pré-release qu'attend outils/qtwebengine-get.sh, fichiers joints AVANT la
# publication : une release immuable n'accepte plus rien après, et son tag est alors perdu. Brouillon
# d'abord : un envoi raté laisse un brouillon, sans tag, à supprimer avant de relancer.
#   GITHUB_TOKEN=<jeton « fine-grained » : Contents en écriture sur vigie-rs> sh outils/qtwebengine-publish.sh
# Sans GITHUB_TOKEN : dist/ seulement, à joindre à la main.
set -eu
cd "$(dirname "$(readlink -f "$0")")/.."
version=$(cut -d, -f1 qtwebengine/version)
tag=$(sh outils/qtwebengine-get.sh "$version" --tag)
a=qtwebengine-linux-x86_64.tar.gz
mkdir -p dist
tar czf "dist/$a" --owner=0 --group=0 qtwebengine
(cd dist && sha256sum "$a" >"$a.sha256")
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "dist/$a et dist/$a.sha256 prêts : à joindre à la pré-release $tag AVANT de la publier."
  exit 0
fi

repo=https://api.github.com/repos/yocarbo/vigie-rs/releases
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Jeton dans un fichier, pas sur la ligne de commande de curl (visible des autres processus).
(umask 077 && printf 'Authorization: Bearer %s\n' "$GITHUB_TOKEN" >"$tmp/auth")
gh() { curl -fsS -H @"$tmp/auth" -H 'Accept: application/vnd.github+json' "$@"; }
json() { python3 -I -c "import json, sys; $1" "$@"; }

new=$(json 'print(json.dumps({"tag_name": sys.argv[2], "target_commitish": "main", "name": "Qt WebEngine " + sys.argv[3],
  "body": "Vigie’s Qt WebEngine, downloaded by `outils/qtwebengine-get.sh`. Not a Vigie release.",
  "draft": True, "prerelease": True}))' "$tag" "$(cat qtwebengine/version)")
id=$(gh -X POST -d "$new" "$repo" | json 'print(json.load(sys.stdin)["id"])')
for f in "$a" "$a.sha256"; do
  gh -X POST -H 'Content-Type: application/octet-stream' --data-binary @"dist/$f" \
    "https://uploads.github.com/repos/yocarbo/vigie-rs/releases/$id/assets?name=$f" >/dev/null \
    || { echo "Envoi de $f raté : brouillon $tag laissé sur GitHub (Releases), à supprimer avant de relancer."; exit 1; }
done
gh -X PATCH -d '{"draft": false}' "$repo/$id" >/dev/null
echo "Pré-release $tag publiée, avec $a et son empreinte."
