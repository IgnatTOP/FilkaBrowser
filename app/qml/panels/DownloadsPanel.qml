import QtQuick
import QtQuick.Controls.Basic
import QtWebEngine
import Filka

// DownloadsPanel — slide-over list of downloads with live progress. Each row
// binds directly to its WebEngineDownloadRequest, so bytes/state update live.
SidePanel {
    id: root
    title: qsTr("Загрузки")

    property var downloads: []
    signal clearList()

    function human(bytes) {
        if (bytes <= 0) return "0 B"
        var u = ["B", "KB", "MB", "GB"]
        var i = Math.floor(Math.log(bytes) / Math.log(1024))
        i = Math.min(i, u.length - 1)
        return (bytes / Math.pow(1024, i)).toFixed(i ? 1 : 0) + " " + u[i]
    }

    Item {
        anchors.fill: parent

        // Empty state.
        Column {
            anchors.centerIn: parent
            spacing: Theme.s3
            visible: root.downloads.length === 0
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

        Flickable {
            anchors.fill: parent
            contentHeight: col.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.downloads.length > 0
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: col
                width: parent.width
                spacing: Theme.s2

                // New downloads drop in at the top and push the rest down.
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
                    NumberAnimation { property: "y"; duration: Motion.base; easing.type: Motion.emphasized }
                }
                move: Transition {
                    NumberAnimation { property: "y"; duration: Motion.base; easing.type: Motion.emphasized }
                }

                Repeater {
                    model: root.downloads
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property int st: modelData.state
                        readonly property bool done: st === WebEngineDownloadRequest.DownloadCompleted
                        readonly property bool failed: st === WebEngineDownloadRequest.DownloadCancelled
                                                       || st === WebEngineDownloadRequest.DownloadInterrupted
                        readonly property real frac: modelData.totalBytes > 0
                                                     ? modelData.receivedBytes / modelData.totalBytes : 0

                        width: parent.width
                        height: 64
                        radius: Theme.radiusMd
                        color: Theme.glassLow
                        border.width: 1; border.color: Theme.glassStroke

                        Icon {
                            id: fileIcon
                            anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                            name: row.done ? "shield-check" : (row.failed ? "x" : "download")
                            size: 18
                            color: row.done ? Theme.positive : (row.failed ? Theme.danger : Theme.accent)
                        }

                        Column {
                            anchors { left: fileIcon.right; right: actionBtn.left
                                      leftMargin: Theme.s3; rightMargin: Theme.s2
                                      verticalCenter: parent.verticalCenter }
                            spacing: 4

                            Text {
                                width: parent.width
                                text: row.modelData.downloadFileName
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                                elide: Text.ElideMiddle
                            }
                            // Progress bar (while downloading) or status line.
                            Rectangle {
                                width: parent.width; height: 4; radius: 2
                                visible: !row.done && !row.failed
                                color: Theme.glassMed
                                Rectangle {
                                    width: parent.width * row.frac
                                    height: parent.height; radius: 2
                                    color: Theme.accent
                                    Behavior on width { NumberAnimation { duration: Motion.fast } }
                                }
                            }
                            Text {
                                width: parent.width
                                visible: row.done || row.failed
                                text: row.done ? qsTr("%1 - завершено").arg(root.human(row.modelData.totalBytes))
                                               : qsTr("отменено")
                                color: row.done ? Theme.textMuted : Theme.danger
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                            }
                        }

                        // Action: open folder when done, cancel while running.
                        IconButton {
                            id: actionBtn
                            anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                            iconName: row.done ? "copy" : "x"
                            size: 30
                            Accessible.name: row.done ? qsTr("Открыть папку") : qsTr("Отменить")
                            onClicked: {
                                if (row.done)
                                    Qt.openUrlExternally("file://" + row.modelData.downloadDirectory)
                                else if (!row.failed)
                                    row.modelData.cancel()
                            }
                        }
                    }
                }

                // Clear list.
                Rectangle {
                    width: parent.width; height: 38
                    radius: Theme.radiusMd
                    color: clearHover.hovered ? Theme.glassMed : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Очистить список")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                    }
                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.clearList() }
                }
            }
        }
    }
}
