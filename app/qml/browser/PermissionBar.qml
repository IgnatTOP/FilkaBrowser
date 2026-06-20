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
    signal siteSettingsRequested()

    implicitHeight: active ? 52 : 0
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    function labelFor(p) {
        if (!p) return ""
        switch (p.permissionType) {
        case WebEnginePermission.Geolocation:            return qsTr("доступ к вашему местоположению")
        case WebEnginePermission.MediaAudioCapture:      return qsTr("доступ к микрофону")
        case WebEnginePermission.MediaVideoCapture:      return qsTr("доступ к камере")
        case WebEnginePermission.MediaAudioVideoCapture: return qsTr("доступ к камере и микрофону")
        case WebEnginePermission.MouseLock:              return qsTr("захват курсора мыши")
        case WebEnginePermission.DesktopVideoCapture:    return qsTr("запись экрана")
        case WebEnginePermission.DesktopAudioVideoCapture:return qsTr("запись экрана и звука")
        case WebEnginePermission.Notifications:          return qsTr("показ уведомлений")
        case WebEnginePermission.ClipboardReadWrite:     return qsTr("доступ к буферу обмена")
        case WebEnginePermission.LocalFontsAccess:       return qsTr("доступ к локальным шрифтам")
        default:                                         return qsTr("дополнительные разрешения")
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
        color: Theme.surface
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
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radiusSm
                implicitHeight: 30
                hPadding: Theme.s3
                fillColor: hovered ? Theme.hoverFill : Theme.surfaceAlt
                accessibleName: qsTr("Открыть настройки сайта")
                onClicked: root.siteSettingsRequested()
                Text {
                    text: qsTr("Настройки сайта")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                }
            }
            Pill {
                id: allowPill
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radiusSm
                implicitHeight: 30
                hPadding: Theme.s4
                strokeWidth: 0
                fillColor: hovered ? Theme.accent : Theme.accentSoft
                accessibleName: qsTr("Разрешить запрос сайта")
                onClicked: root.grant()
                Text {
                    text: qsTr("Разрешить")
                    color: allowPill.hovered ? Theme.accentForeground : Theme.accentSoftForeground
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                }
            }
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radiusSm
                implicitHeight: 30
                hPadding: Theme.s4
                fillColor: hovered ? Theme.hoverFill : Theme.surfaceAlt
                accessibleName: qsTr("Запретить запрос сайта")
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
