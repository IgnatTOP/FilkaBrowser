import QtQuick
import QtQuick.Controls.Basic
import Filka

// DownloadsPanel — slide-over list of downloads with live progress and history.
SidePanel {
    id: root
    title: qsTr("Загрузки")

    property bool privateMode: false
    readonly property int visibleDownloadCount: privateMode ? DownloadModel.count : DownloadModel.publicCount

    signal clearList()

    Item {
        anchors.fill: parent

        Column {
            anchors.centerIn: parent
            spacing: Theme.s3
            visible: root.visibleDownloadCount === 0
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "download"; size: 40; color: Theme.textMuted
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Загрузок пока нет")
                color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
            }
        }

        ListView {
            id: list
            anchors.fill: parent
            visible: root.visibleDownloadCount > 0
            clip: true
            spacing: Theme.s2
            model: DownloadModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FilkaScrollBar {}

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
                NumberAnimation { property: "y"; duration: Motion.base; easing.type: Motion.emphasized }
            }
            move: Transition {
                NumberAnimation { property: "y"; duration: Motion.base; easing.type: Motion.emphasized }
            }

            delegate: Rectangle {
                id: row
                required property int downloadId
                required property string fileName
                required property string statusText
                required property real progress
                required property bool finished
                required property bool failed
                required property bool activeDownload
                required property bool paused
                required property bool privateDownload
                readonly property bool visibleInPanel: root.privateMode || !row.privateDownload

                width: ListView.view.width
                height: visibleInPanel ? 64 : 0
                visible: visibleInPanel
                radius: Theme.radiusMd
                color: Theme.card
                border.width: 1
                border.color: Theme.outline

                Icon {
                    id: fileIcon
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    name: row.finished && !row.failed ? "shield-check" : (row.failed ? "x" : "download")
                    size: 18
                    color: row.finished && !row.failed ? Theme.positive : (row.failed ? Theme.danger : Theme.accent)
                }

                Column {
                    anchors { left: fileIcon.right; right: pauseBtn.visible ? pauseBtn.left : actionBtn.left
                              leftMargin: Theme.s3; rightMargin: Theme.s2
                              verticalCenter: parent.verticalCenter }
                    spacing: 4

                    Text {
                        width: parent.width
                        text: row.fileName
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        width: parent.width; height: 4; radius: 2
                        visible: row.activeDownload
                        color: Theme.surfaceAlt
                        Rectangle {
                            width: parent.width * row.progress
                            height: parent.height; radius: 2
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: Motion.fast } }
                        }
                    }
                    Text {
                        width: parent.width
                        text: row.statusText
                        color: row.failed ? Theme.danger : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    id: pauseBtn
                    anchors { right: actionBtn.left; rightMargin: Theme.s1; verticalCenter: parent.verticalCenter }
                    visible: row.activeDownload
                    iconName: row.paused ? "rotate-cw" : "minus"
                    size: 30
                    Accessible.name: row.paused ? qsTr("Продолжить") : qsTr("Пауза")
                    onClicked: row.paused ? DownloadModel.resume(row.downloadId)
                                          : DownloadModel.pause(row.downloadId)
                }

                IconButton {
                    id: actionBtn
                    anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                    iconName: row.finished && !row.failed ? "download" : "x"
                    size: 30
                    Accessible.name: row.finished && !row.failed ? qsTr("Открыть файл") : qsTr("Отменить")
                    onClicked: {
                        if (row.finished && !row.failed)
                            DownloadModel.open(row.downloadId)
                        else if (row.activeDownload)
                            DownloadModel.cancel(row.downloadId)
                        else
                            DownloadModel.remove(row.downloadId)
                    }
                }
            }

            footer: Rectangle {
                width: list.width
                height: 38
                radius: Theme.radiusSm
                color: clearHover.hovered ? Theme.hoverFill : "transparent"
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Очистить завершённые загрузки")
                Keys.onReturnPressed: root.clearList()
                Keys.onEnterPressed: root.clearList()
                Keys.onSpacePressed: root.clearList()
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Очистить завершённые")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.clearList() }
            }
        }
    }
}
