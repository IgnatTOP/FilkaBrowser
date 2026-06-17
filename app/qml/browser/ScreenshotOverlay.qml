import QtQuick
import QtQuick.Layouts
import Filka

FocusScope {
    id: root

    property bool active: false
    property bool copyToClipboard: false
    property rect selectionRect: Qt.rect(0, 0, 0, 0)
    property point origin: Qt.point(0, 0)

    signal accepted(rect selection, bool copyToClipboard)
    signal cancelled()

    visible: active
    focus: active
    z: 999
    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Выделение области скриншота")

    function start(copy) {
        copyToClipboard = copy === true
        selectionRect = Qt.rect(0, 0, 0, 0)
        active = true
        forceActiveFocus()
    }

    function stop() {
        active = false
        selectionRect = Qt.rect(0, 0, 0, 0)
    }

    function normalizedRect(a, b) {
        const x = Math.min(a.x, b.x)
        const y = Math.min(a.y, b.y)
        return Qt.rect(x, y, Math.abs(a.x - b.x), Math.abs(a.y - b.y))
    }

    function acceptSelection() {
        if (selectionRect.width < 8 || selectionRect.height < 8)
            return
        const rect = selectionRect
        stop()
        accepted(rect, copyToClipboard)
    }

    Keys.onEscapePressed: {
        stop()
        cancelled()
    }
    Keys.onReturnPressed: acceptSelection()
    Keys.onEnterPressed: acceptSelection()

    Rectangle {
        anchors.fill: parent
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(0, 0, 0, 0.30)
        z: -1
    }

    Rectangle {
        x: root.selectionRect.x
        y: root.selectionRect.y
        width: root.selectionRect.width
        height: root.selectionRect.height
        visible: width > 0 && height > 0
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        z: 1
    }

    Rectangle {
        visible: selectionRect.width > 0 && selectionRect.height > 0
        x: Math.min(root.width - width - Theme.s2, selectionRect.x + selectionRect.width + Theme.s2)
        y: Math.min(root.height - height - Theme.s2, selectionRect.y + selectionRect.height + Theme.s2)
        width: sizeText.implicitWidth + Theme.s3
        height: 28
        radius: Theme.radiusPill
        color: Theme.bgRaised
        border.width: 1
        border.color: Theme.glassStroke
        z: 2

        Text {
            id: sizeText
            anchors.centerIn: parent
            text: "%1 x %2".arg(Math.round(selectionRect.width)).arg(Math.round(selectionRect.height))
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            font.weight: Font.Medium
        }
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.s5
        spacing: Theme.s2
        z: 2

        Rectangle {
            Layout.preferredWidth: hintText.implicitWidth + Theme.s5
            Layout.preferredHeight: 34
            radius: Theme.radiusPill
            color: Theme.bgRaised
            border.width: 1
            border.color: Theme.glassStroke
            Text {
                id: hintText
                anchors.centerIn: parent
                text: qsTr("Потяните область, Enter - сохранить, Escape - отменить")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
            }
        }
        IconButton {
            iconName: "check"
            size: Theme.controlMd
            enabled: root.selectionRect.width >= 8 && root.selectionRect.height >= 8
            opacity: enabled ? 1 : 0.42
            Accessible.name: qsTr("Сохранить скриншот")
            onClicked: root.acceptSelection()
        }
        IconButton {
            iconName: "x"
            size: Theme.controlMd
            Accessible.name: qsTr("Отменить скриншот")
            onClicked: {
                root.stop()
                root.cancelled()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        cursorShape: Qt.CrossCursor
        onPressed: (mouse) => {
            root.origin = Qt.point(mouse.x, mouse.y)
            root.selectionRect = Qt.rect(mouse.x, mouse.y, 0, 0)
        }
        onPositionChanged: (mouse) => {
            if (pressed)
                root.selectionRect = root.normalizedRect(root.origin, Qt.point(mouse.x, mouse.y))
        }
        onReleased: (mouse) => {
            root.selectionRect = root.normalizedRect(root.origin, Qt.point(mouse.x, mouse.y))
        }
    }
}
