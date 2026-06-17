import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Popup {
    id: root

    signal captureFull(bool copyToClipboard)
    signal selectArea(bool copyToClipboard)

    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    padding: 0
    implicitWidth: 260

    function showAt(item) {
        if (item) {
            const point = item.mapToItem(parent, 0, item.height + Theme.s1)
            x = Math.min(parent.width - implicitWidth - Theme.s2, Math.max(Theme.s2, point.x + item.width - implicitWidth))
            y = Math.min(parent.height - implicitHeight - Theme.s2, Math.max(Theme.s2, point.y))
        }
        open()
    }

    enter: Transition {
        OpacityAnimator { from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
        ScaleAnimator { from: 0.96; to: 1; duration: Motion.fast; easing.type: Motion.emphasized }
    }
    exit: Transition {
        OpacityAnimator { from: 1; to: 0; duration: Motion.instant; easing.type: Motion.exit }
    }

    background: Rectangle {
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.glassStroke
    }

    component CaptureRow: Rectangle {
        id: row
        property string iconName: "camera"
        property string title: ""
        property string subtitle: ""
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: Theme.radiusMd
        color: hover.hovered ? Theme.hoverFill : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: title

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s3
            anchors.rightMargin: Theme.s3
            spacing: Theme.s3

            Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                name: row.iconName
                size: 18
                color: Theme.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: row.title
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: row.subtitle
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideRight
                }
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.triggered() }
        Keys.onReturnPressed: row.triggered()
        Keys.onEnterPressed: row.triggered()
        Keys.onSpacePressed: row.triggered()
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    contentItem: ColumnLayout {
        spacing: Theme.s1

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s4
            spacing: Theme.s2

            Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                name: "camera"
                size: 19
                color: Theme.accent
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Скриншот")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMd
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.glassHairline
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s2
            spacing: Theme.s1

            CaptureRow {
                iconName: "camera"
                title: qsTr("Видимая область")
                subtitle: qsTr("Сохранить PNG в загрузки")
                onTriggered: {
                    root.close()
                    root.captureFull(false)
                }
            }
            CaptureRow {
                iconName: "crop"
                title: qsTr("Выделить область")
                subtitle: qsTr("Захватить фрагмент страницы")
                onTriggered: {
                    root.close()
                    root.selectArea(false)
                }
            }
            CaptureRow {
                iconName: "clipboard"
                title: qsTr("В буфер обмена")
                subtitle: qsTr("Скопировать PNG")
                onTriggered: {
                    root.close()
                    root.captureFull(true)
                }
            }
        }
    }
}
