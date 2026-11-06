//! Application Qt créée en C++ (cpp/app.h) : cxx-qt-lib n'expose ni QApplication ni ces appels statiques.
#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;

        include!("app.h");
        type QApplication;

        /// Avant l'application : Qt WebEngine, et l'id de l'app (fichier .desktop, icône sous Wayland).
        fn vigie_prepare();
        /// L'application (nom affiché).
        fn vigie_application() -> UniquePtr<QApplication>;
        /// Thème du système sombre (après l'application).
        fn vigie_system_dark() -> bool;
        /// Icône des fenêtres : les PNG de `dir`, sinon celle du thème.
        fn vigie_window_icon(dir: &QString);
        /// Boucle d'événements ; renvoie le code de sortie.
        fn vigie_exec() -> i32;
    }
}
