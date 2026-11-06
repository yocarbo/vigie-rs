// Logo d'un service dans une case fixe : logo de la recipe, sinon favicon du site, sinon initiales.
import QtQuick
import QtQuick.Controls

Item {
    id: logo
    property string name
    // Logo de la recipe ou favicon (vide : initiales).
    property string source
    property int size: 32

    width: size
    height: size
    clip: true

    Image {
        id: picture
        anchors.fill: parent
        source: logo.source
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        sourceSize: Qt.size(88, 88)
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !picture.visible
        color: Qt.hsla(((logo.name.charCodeAt(0) || 0) * 37 % 360) / 360, 0.55, 0.5, 1)
        Label {
            anchors.centerIn: parent
            text: logo.name.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0]).join("").toUpperCase()
            color: "white"
            font.bold: true
            font.pixelSize: Math.round(logo.size * 0.4)
        }
    }
}
