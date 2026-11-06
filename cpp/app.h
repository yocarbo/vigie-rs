#pragma once
#include <memory>

#include <QtCore/QString>
#include <QtGui/QIcon>
#include <QtGui/QStyleHints>
#include <QtWidgets/QApplication>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

inline void vigie_prepare()
{
    QtWebEngineQuick::initialize();
    // Sous Wayland, le bureau associe la fenêtre au fichier io.github.vigie_rs.desktop (et à son icône).
    QGuiApplication::setDesktopFileName(QStringLiteral("io.github.vigie_rs"));
}

// QApplication et non QGuiApplication : sous KDE, l'intégration Qt fournit des dialogues et des
// menus natifs écrits en widgets, qui exigent une QApplication.
inline std::unique_ptr<QApplication> vigie_application()
{
    static int argc = 1;
    static char name[] = "vigie-rs";
    static char *argv[] = {name, nullptr};
    auto app = std::make_unique<QApplication>(argc, argv);
    QApplication::setApplicationName(QStringLiteral("vigie-rs"));
    QApplication::setApplicationDisplayName(QStringLiteral("Vigie"));
    return app;
}

inline bool vigie_system_dark()
{
    return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
}

// Icône de toutes les fenêtres (KWin la lit aussi sous Wayland) : les PNG de Vigie rendus dans `dir`,
// sinon celle du thème (installée par ./vigie-rs install).
inline void vigie_window_icon(const QString &dir)
{
    QIcon icon;
    for (int size : {16, 24, 32, 48, 64, 128, 256})
        icon.addFile(dir + QStringLiteral("/app-%1.png").arg(size), QSize(size, size));
    if (icon.availableSizes().isEmpty())
        icon = QIcon::fromTheme(QStringLiteral("io.github.vigie_rs"));
    QApplication::setWindowIcon(icon);
}

inline int vigie_exec()
{
    return QApplication::exec();
}
