# Environnement de compilation et de test de vigie-rs (Rust + cxx-qt + Qt 6 WebEngine).
# Ubuntu 26.04 : même Qt (6.10) que le poste de développement. Le code est monté dans /app :
#   docker build -t vigie-rs-dev .
#   docker run --rm -v "$PWD":/app -v vigie-rs-cargo:/usr/local/cargo/registry -v vigie-rs-target:/app/target vigie-rs-dev
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential pkg-config curl ca-certificates lld \
      qmake6 qt6-base-dev qt6-declarative-dev qt6-webengine-dev qt6-webchannel-dev \
      qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
      qml6-module-qtquick-window qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
      qml6-module-qtqml-workerscript qml6-module-qtwebengine qml6-module-qtwebchannel \
      qml6-module-qt-labs-platform qml6-module-qtcore \
      qt6-webengine-dev-tools hunspell-fr hunspell-en-us \
      libgl1-mesa-dri libegl1 fonts-dejavu-core \
      nodejs xvfb xauth dbus scrot xdotool \
 && rm -rf /var/lib/apt/lists/* \
 && curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path

WORKDIR /app
CMD ["sh", "test/run.sh"]
