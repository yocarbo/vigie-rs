#!/bin/sh
# Qt WebEngine de Vigie, avec VA-API (vidéo décodée par la carte graphique, dont le H.265 des caméras).
# Ubuntu compile Qt WebEngine avec la libvpx du système, et Qt désactive alors VA-API : on recompile
# le paquet d'Ubuntu à l'identique (même version, mêmes correctifs), sauf la libvpx, intégrée.
# Dans le conteneur (image vigie-rs-dev : même Ubuntu, même Qt que l'hôte), appelé par ./vigie-rs ;
# plusieurs heures, une quinzaine de Go dans /build. Résultat dans qtwebengine/, à côté de Vigie :
# lib/, libexec/QtWebEngineProcess, resources/, translations/, qml/ (Vigie les préfère au système).
#   sh outils/qtwebengine.sh <uid> <gid>
set -eu
owner=${1:-0}:${2:-0}
repo=$PWD
work=/build
# Une tâche par 3 Go de mémoire libre : certains fichiers de Chromium en prennent autant, et au-delà
# le compilateur est tué (« Killed signal terminated program cc1plus »).
jobs=${JOBS:-$(awk '/MemAvailable/ { j = int($2 / 3145728); print j < 1 ? 1 : j }' /proc/meminfo)}

# Sources et dépendances de compilation du paquet d'Ubuntu.
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get build-dep -y -qq qt6-webengine >/dev/null
apt-get install -y -qq --no-install-recommends libva-dev libgbm-dev patchelf >/dev/null
mkdir -p $work
cd $work
[ -d qt6-webengine-*/ ] || apt-get source -qq qt6-webengine
cd qt6-webengine-*/
version=$(dpkg-parsechangelog -S Version)
[ "$version" = "$(dpkg-query -W -f '${Version}' libqt6webenginecore6)" ] \
  || { echo "qt6-webengine $version ≠ paquet installé"; exit 1; }

# Première différence : libvpx intégrée, et VA-API exigé (la configuration échoue s'il manque).
grep -q 'webengine_vaapi=ON' debian/rules || sed -i -e 's/ *-DFEATURE_webengine_system_libvpx=ON//' \
  -e 's/-DFEATURE_webengine_kerberos=ON/& -DFEATURE_webengine_system_libvpx=OFF -DFEATURE_webengine_vaapi=ON/' debian/rules
grep -q 'webengine_vaapi=ON' debian/rules || { echo "debian/rules : options non ajoutées"; exit 1; }
# Seconde différence : Vigie ne bloque jamais la mise en veille. Sinon, Chromium la bloque tant
# qu'un son joue ou qu'une vidéo est visible (le direct d'une caméra, par exemple).
blocker=src/3rdparty/chromium/services/device/wake_lock/power_save_blocker/power_save_blocker_linux.cc
grep -q 'return false && !base::CommandLine' $blocker \
  || sed -i 's/^  return !base::CommandLine::ForCurrentProcess()->HasSwitch($/  return false \&\& !base::CommandLine::ForCurrentProcess()->HasSwitch(/' $blocker
grep -q 'return false && !base::CommandLine' $blocker || { echo "$blocker : veille non débloquée"; exit 1; }
# Compilation avec la glibc d'aujourd'hui : la définition de secours de SYS_SECCOMP (1) casse
# l'enum de <signal.h> quand celui-ci vient après ; inclus avant, c'est celle de glibc qui sert.
seccomp=src/3rdparty/chromium/sandbox/linux/system_headers/linux_seccomp.h
grep -q '^#include <signal.h>' $seccomp || sed -i 's/^#include <stdint.h>$/#include <signal.h>\n&/' $seccomp
grep -q '^#include <signal.h>' $seccomp || { echo "$seccomp : SYS_SECCOMP non corrigé"; exit 1; }
# Reprise après interruption : sans nettoyage, ninja repart où il en était.
clean=
[ -d obj-x86_64-linux-gnu ] && clean=-nc
# Chromium se compile dans un second ninja, qui ignore NINJAJOBS et lance sinon une tâche par
# processeur : son -j vient de NINJAFLAGS, lu à la configuration, et se corrige ici à la reprise.
export NINJAFLAGS=-j$jobs
[ -f obj-x86_64-linux-gnu/build.ninja ] \
  && sed -i -E "s#(/ninja )(-j[0-9]+ )?(-v )?-C #\1-j$jobs \3-C #" obj-x86_64-linux-gnu/build.ninja
NINJAJOBS=-j$jobs DEB_BUILD_OPTIONS="nocheck nodoc noautodbgsym parallel=$jobs" \
  dpkg-buildpackage -b -uc -us $clean

# Fichiers d'exécution des paquets produits, rangés pour Vigie.
stage=$work/stage
rm -rf $stage
for deb in libqt6webenginecore6 libqt6webenginecore6-bin libqt6webengine6-data libqt6webenginequick6 \
  libqt6webenginequickdelegatesqml6 qml6-module-qtwebengine qml6-module-qtwebengine-controlsdelegates; do
  f=$(ls ../${deb}_*.deb 2>/dev/null | head -1)
  [ -n "$f" ] && dpkg-deb -x "$f" $stage
done
out=$work/qtwebengine
rm -rf $out
mkdir -p $out/lib $out/libexec $out/translations
cp -a $stage/usr/lib/x86_64-linux-gnu/libQt6WebEngine*.so.6* $out/lib/
cp -a $stage/usr/lib/qt6/libexec/QtWebEngineProcess $out/libexec/
cp -a $stage/usr/share/qt6/resources $out/resources
cp -a $stage/usr/share/qt6/translations/qtwebengine_locales $out/translations/
cp -a $stage/usr/lib/x86_64-linux-gnu/qt6/qml $out/qml
cp $stage/usr/share/doc/libqt6webenginecore6/copyright $out/copyright
# Chacun cherche d'abord les bibliothèques d'ici, pas celles du système.
patchelf --set-rpath '$ORIGIN/../lib' $out/libexec/QtWebEngineProcess
for f in $(find $out/lib $out/qml -name '*.so*' -type f); do
  patchelf --set-rpath "\$ORIGIN/$(realpath --relative-to="$(dirname "$f")" $out/lib)" "$f"
done
echo "$version, VA-API" >$out/version

rm -rf "$repo/qtwebengine"
cp -a $out "$repo/qtwebengine"
chown -R $owner "$repo/qtwebengine"
echo "Qt WebEngine $version (VA-API) dans qtwebengine/"
