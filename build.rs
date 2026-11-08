use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    // Gravés dans le binaire pour les mises à jour (src/update.rs) : passés par ./vigie-rs ou la GitHub Action.
    for var in ["VIGIE_COMMIT", "VIGIE_CHANNEL"] {
        println!("cargo:rerun-if-env-changed={var}");
        println!("cargo:rustc-env={var}={}", std::env::var(var).unwrap_or_default());
    }
    let qml = [
        "qml/Main.qml",
        "qml/ServiceView.qml",
        "qml/ServiceIcon.qml",
        "qml/ServiceLogo.qml",
        "qml/InternalWindow.qml",
        "qml/SettingsDialog.qml",
        "qml/ServiceEditor.qml",
        "qml/WebAuthWindow.qml",
    ];
    CxxQtBuilder::new_qml_module(QmlModule::new("Vigie").qml_files(qml))
        .files(["src/backend.rs", "src/qtapp.rs"])
        .include_dir("cpp")
        .qt_module("Gui")
        .qt_module("Widgets")
        .qt_module("Quick")
        .qt_module("WebEngineQuick")
        .build();
}
