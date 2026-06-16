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

        Icon {
            id: promptIcon
            anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            name: "shield"; size: 16; color: Theme.accent
        }
        Text {
            anchors { left: promptIcon.right; leftMargin: Theme.s2; right: actions.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            text: qsTr("%1 запрашивает %2").arg(root.host(root.permission)).arg(root.labelFor(root.permission))
            color: Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
            elide: Text.ElideRight
        }

        Row {
            id: actions
            anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
            spacing: Theme.s2

            Pill {
                id: allowPill
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radiusSm
                implicitHeight: 30
                hPadding: Theme.s4
                strokeWidth: 0
                fillColor: hovered ? Theme.accent : Theme.accentSoft
                onClicked: root.grant()
                Text {
                    text: qsTr("Разрешить")
                    color: allowPill.hovered ? "white" : Theme.accent
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                }
            }
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radiusSm
                implicitHeight: 30
                hPadding: Theme.s4
                fillColor: hovered ? Theme.glassHigh : Theme.glassLow
                onClicked: root.deny()
                Text {
                    text: qsTr("Запретить")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                }
            }
        }
    }
}
