import QtQuick
import QtWebEngine
import Filka

// PermissionBar — a slim prompt for site permission requests. Qt 6.8 exposes
// WebEnginePermission.grant()/deny() and profile-level persistence, but no
// per-call duration flag, so “always/block” choices are persisted by
// AppSettings and replayed before the next prompt. “One time” only resolves the
// live permission object.
Item {
    id: root
    property var permission: null
    property bool privateMode: false
    property bool active: permission !== null
    signal decided()
    signal openSiteSettings()

    implicitHeight: active ? 64 : 0
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Motion.base; easing.type: Motion.emphasized } }

    function labelFor(p) {
        if (!p) return ""
        switch (p.permissionType) {
        case WebEnginePermission.Geolocation:             return qsTr("местоположению")
        case WebEnginePermission.MediaAudioCapture:       return qsTr("микрофону")
        case WebEnginePermission.MediaVideoCapture:       return qsTr("камере")
        case WebEnginePermission.MediaAudioVideoCapture:  return qsTr("камере и микрофону")
        case WebEnginePermission.MouseLock:               return qsTr("захвату курсора")
        case WebEnginePermission.DesktopVideoCapture:     return qsTr("записи экрана")
        case WebEnginePermission.DesktopAudioVideoCapture:return qsTr("записи экрана и звука")
        case WebEnginePermission.Notifications:           return qsTr("уведомлениям")
        case WebEnginePermission.ClipboardReadWrite:      return qsTr("буферу обмена")
        case WebEnginePermission.LocalFontsAccess:        return qsTr("локальным шрифтам")
        default:                                          return qsTr("дополнительным возможностям")
        }
    }
    function host(p) {
        if (!p) return ""
        var s = p.origin.toString()
        return s.replace(/^https?:\/\//, "").replace(/\/$/, "")
    }
    function explanationFor(p) {
        if (!p) return ""
        return qsTr("%1 хочет доступ к %2").arg(root.host(p)).arg(root.labelFor(p))
    }

    function allowOnce() {
        if (permission)
            permission.grant()
        root.decided()
    }
    function allowAlways() {
        if (permission) {
            if (!root.privateMode)
                AppSettings.setSitePermissionDecision(permission.origin.toString(), permission.permissionType, "allow")
            permission.grant()
        }
        root.decided()
    }
    function deny() {
        if (permission) {
            if (!root.privateMode)
                AppSettings.setSitePermissionDecision(permission.origin.toString(), permission.permissionType, "block")
            permission.deny()
        }
        root.decided()
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: Theme.s3; rightMargin: Theme.s3 }
        height: 56
        radius: Theme.radiusMd
        color: Theme.surface
        border.width: 1
        border.color: Theme.accent

        Icon {
            id: promptIcon
            anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            name: "shield"; size: 16; color: Theme.accent
        }
        Column {
            anchors { left: promptIcon.right; leftMargin: Theme.s2; right: actions.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                width: parent.width
                text: root.explanationFor(root.permission)
                color: Theme.textPrimary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.privateMode ? qsTr("В приватном окне долгосрочные разрешения не сохраняются.")
                                       : qsTr("Выберите одноразовое или постоянное правило для этого сайта.")
                color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                elide: Text.ElideRight
            }
        }

        Row {
            id: actions
            anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
            spacing: Theme.s2

            PillButton { label: qsTr("Настройки сайта"); onClicked: root.openSiteSettings() }
            PillButton { label: qsTr("Разрешить один раз"); primary: true; onClicked: root.allowOnce() }
            PillButton { label: root.privateMode ? qsTr("Разрешить") : qsTr("Всегда для сайта"); enabled: !root.privateMode; onClicked: root.allowAlways() }
            PillButton { label: qsTr("Запретить"); onClicked: root.deny() }
        }
    }

    component PillButton: Pill {
        property string label: ""
        property bool primary: false
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.radiusSm
        implicitHeight: 30
        hPadding: Theme.s3
        strokeWidth: primary ? 0 : 1
        fillColor: primary ? (hovered ? Theme.accent : Theme.accentSoft) : (hovered ? Theme.hoverFill : Theme.surfaceAlt)
        accessibleName: label
        Text {
            text: parent.label
            color: parent.primary ? (parent.hovered ? Theme.accentForeground : Theme.accentSoftForeground) : Theme.textSecondary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: parent.primary ? Font.Medium : Font.Normal
        }
    }
}
