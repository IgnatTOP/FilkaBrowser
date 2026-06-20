pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

FocusScope {
    id: root

    required property var browser
    required property ShellState shell
    property bool open: false

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    z: 490
    focus: open
    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

    function hostOf(url) {
        var s = ("" + url).replace(/^[a-z]+:\/\//i, "").replace(/^www\./i, "")
        var slash = s.indexOf("/")
        return slash >= 0 ? s.slice(0, slash) : s
    }

    function close() { shell.closeOverlays() }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrimSoft
        TapHandler { onTapped: root.close() }
    }

    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: Theme.s5 }
        width: Math.min(420, parent.width - Theme.s6)
        height: content.implicitHeight + Theme.s4 * 2
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.outline

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                Icon {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    name: browser.isSecure ? "lock" : "globe"
                    size: 22
                    color: browser.isSecure ? Theme.positive : Theme.warning
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: root.hostOf(browser.currentUrl)
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: browser.isSecure ? qsTr("Защищённое соединение") : qsTr("Соединение не защищено")
                        color: browser.isSecure ? Theme.positive : Theme.warning
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                IconButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    iconName: "x"
                    size: 28
                    iconSize: 13
                    Accessible.name: qsTr("Закрыть")
                    onClicked: root.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: browser.currentUrl
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                elide: Text.ElideMiddle
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outline
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Pill {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    accessibleName: qsTr("Сбросить масштаб")
                    onClicked: browser.resetZoom()
                    Text {
                        text: qsTr("Масштаб %1%").arg(Math.round(browser.zoomFactor * 100))
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Pill {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    accessibleName: qsTr("Копировать URL")
                    onClicked: PageTranslator.copyToClipboard(browser.currentUrl)
                    Text {
                        text: qsTr("Копировать URL")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Pill {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    accessibleName: qsTr("Сбросить разрешения для текущего сайта")
                    onClicked: BrowsingData.clearPermissionsForOrigin(browser.profile, browser.currentUrl)
                    Text {
                        text: qsTr("Сбросить разрешения")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Pill {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    accessibleName: qsTr("Очистить cookies текущего сайта")
                    onClicked: BrowsingData.clearCookiesForOrigin(browser.profile, browser.currentUrl)
                    Text {
                        text: qsTr("Очистить cookies")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
