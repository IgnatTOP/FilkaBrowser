import QtQuick
import QtWebEngine
import Filka

// PermissionBar — a slim allow/block prompt for site permission requests
// (camera, microphone, location, notifications). Sits in the chrome strip so it
// renders above web content. `permission` is a live WebEnginePermission.
Item {
    id: root
    property var permission: null
    property bool active: permission !== null
    signal decided()

    implicitHeight: active ? 52 : 0
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    function labelFor(p) {
        if (!p) return ""
        switch (p.permissionType) {
        case WebEnginePermission.Geolocation:            return "доступ к вашему местоположению"
        case WebEnginePermission.MediaAudioCapture:      return "доступ к микрофону"
        case WebEnginePermission.MediaVideoCapture:      return "доступ к камере"
        case WebEnginePermission.MediaAudioVideoCapture: return "доступ к камере и микрофону"
        case WebEnginePermission.MouseLock:              return "захват курсора мыши"
        case WebEnginePermission.DesktopVideoCapture:    return "запись экрана"
        case WebEnginePermission.DesktopAudioVideoCapture:return "запись экрана и звука"
        case WebEnginePermission.Notifications:          return "показ уведомлений"
        case WebEnginePermission.ClipboardReadWrite:     return "доступ к буферу обмена"
        case WebEnginePermission.LocalFontsAccess:       return "доступ к локальным шрифтам"
        default:                                         return "дополнительные разрешения"
        }
    }
    function host(p) {
        if (!p) return ""
        var s = p.origin.toString()
        return s.replace(/^https?:\/\//, "").replace(/\/.*$/, "")
    }

    function grant() { if (permission) permission.grant(); root.decided() }
    function deny()  { if (permission) permission.deny();  root.decided() }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: Theme.s3; rightMargin: Theme.s3 }
        height: 44
        radius: Theme.radiusMd
        color: Theme.glassHigh
        border.width: 1
        border.color: Theme.accent

        Row {
            anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            spacing: Theme.s2
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "shield"; size: 16; color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.host(root.permission) + " запрашивает " + root.labelFor(root.permission)
                color: Theme.textPrimary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                elide: Text.ElideRight
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
            spacing: Theme.s2

            Rectangle {
                width: 90; height: 30; radius: Theme.radiusSm
                color: allowHover.hovered ? Theme.accent : Theme.accentSoft
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Text {
                    anchors.centerIn: parent; text: "Разрешить"
                    color: allowHover.hovered ? "white" : Theme.accent
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                }
                HoverHandler { id: allowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.grant() }
            }
            Rectangle {
                width: 96; height: 30; radius: Theme.radiusSm
                color: blockHover.hovered ? Theme.glassHigh : Theme.glassLow
                border.width: 1; border.color: Theme.glassStroke
                Text {
                    anchors.centerIn: parent; text: "Запретить"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                }
                HoverHandler { id: blockHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.deny() }
            }
        }
    }
}
