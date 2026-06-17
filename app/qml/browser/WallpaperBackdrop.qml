import QtQuick
import Filka

Item {
    id: root

    property string preset: "coast"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#130D21" }
            GradientStop { position: 0.52; color: "#11182D" }
            GradientStop { position: 1.0; color: "#020711" }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.preset === "coast"
                ? "qrc:/qt/qml/Filka/assets/wallpapers/filka-coast.png"
                : ""
        sourceSize: Qt.size(2400, 1350)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.025, 0.045, 0.12) }
            GradientStop { position: 0.48; color: Qt.rgba(0.02, 0.025, 0.045, 0.30) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.015, 0.030, 0.76) }
        }
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.min(380, parent.width * 0.30)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.00, 0.01, 0.02, 0.64) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
