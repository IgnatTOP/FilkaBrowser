import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Window {
    id: root

    default property alias content: contentSlot.data

    property url sourceUrl: ""

    function open() {
        visible = true
        raise()
        requestActivate()
    }

    function toggle() {
        if (visible)
            close()
        else
            open()
    }

    width: 420
    height: 260
    minimumWidth: 300
    minimumHeight: 190
    visible: false
    title: qsTr("Картинка в картинке")
    color: Theme.bgBase
    flags: Qt.Window | Qt.WindowStaysOnTopHint

    Rectangle {
        anchors.fill: parent
        color: Theme.bgBase

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.leftMargin: Theme.s3
                Layout.rightMargin: Theme.s2
                spacing: Theme.s2

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSm
                        color: Theme.accentSoft
                        border.width: 1
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "square"
                        size: 14
                        color: Theme.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: root.title.length > 0 ? root.title : qsTr("Картинка в картинке")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.DemiBold
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.sourceUrl.toString().length > 0
                              ? root.sourceUrl.toString()
                              : qsTr("Источник не выбран")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        maximumLineCount: 1
                        elide: Text.ElideMiddle
                    }
                }

                IconButton {
                    Layout.preferredWidth: size
                    Layout.preferredHeight: size
                    iconName: "x"
                    size: Theme.controlMd
                    Accessible.name: qsTr("Закрыть")
                    onClicked: root.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassHairline
            }

            Item {
                id: mediaFrame

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Theme.s2
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: Theme.bgSunken
                    border.width: 1
                    border.color: Theme.glassStroke
                }

                Item {
                    id: contentSlot
                    anchors.fill: parent
                    anchors.margins: 1
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Theme.s6, 280)
                    visible: contentSlot.children.length === 0
                    spacing: Theme.s3

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        name: "globe"
                        size: 34
                        color: Theme.textMuted
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.sourceUrl.toString().length > 0
                              ? root.title
                              : qsTr("PiP ожидает медиа")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.sourceUrl.toString().length > 0
                              ? root.sourceUrl.toString()
                              : qsTr("Передайте sourceUrl и при необходимости вложенный медиа-элемент.")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 2
                        elide: Text.ElideMiddle
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: StandardKey.Cancel
        onActivated: root.close()
    }
}
