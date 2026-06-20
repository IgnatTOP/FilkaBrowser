import QtQuick
import QtQuick.Controls.Basic
import Filka

Popup {
    id: root

    property string message: ""
    property var undoCallback: null

    function show(text, callback) {
        message = text
        undoCallback = callback
        open()
        closeTimer.restart()
    }

    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? parent.height - height - Theme.s6 : 0
    padding: Theme.s3
    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight
    Accessible.role: Accessible.AlertMessage
    Accessible.name: message

    onClosed: closeTimer.stop()

    Timer {
        id: closeTimer
        interval: Motion.actionFeedbackTimeout
        onTriggered: root.close()
    }

    background: Rectangle {
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.outline
    }

    function undo() {
        if (root.undoCallback)
            root.undoCallback()
        root.close()
    }

    contentItem: Row {
        id: body
        spacing: Theme.s3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.message
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: undoText.implicitWidth + Theme.s4
            height: 30
            radius: Theme.radiusPill
            color: undoHover.hovered ? Theme.activeFill : Theme.hoverFill
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Отменить удаление")
            Text {
                id: undoText
                anchors.centerIn: parent
                text: qsTr("Отменить")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold
            }
            HoverHandler { id: undoHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.undo() }
            Keys.onReturnPressed: root.undo()
            Keys.onEnterPressed: root.undo()
            Keys.onSpacePressed: root.undo()
        }
    }
}
