import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Popup {
    id: root

    property var mediaTabs: []
    property string currentUrl: ""
    property string currentTitle: ""

    signal requestActivate(var tabId)
    signal requestMute(var tabId, bool muted)
    signal requestPlayPause(var tabId)
    signal requestPauseAll()

    readonly property bool useArrayModel: Array.isArray(mediaTabs)
    readonly property string currentLabel: currentTitle.length > 0 ? currentTitle : currentUrl

    function roleValue(row, names, fallbackValue) {
        if (!row)
            return fallbackValue

        for (var i = 0; i < names.length; ++i) {
            var value = row[names[i]]
            if (value !== undefined && value !== null)
                return value
        }

        return fallbackValue
    }

    function stringValue(value) {
        return value === undefined || value === null ? "" : String(value)
    }

    function boolValue(value, fallbackValue) {
        if (value === undefined || value === null)
            return fallbackValue
        if (typeof value === "boolean")
            return value
        if (typeof value === "number")
            return value !== 0

        var text = String(value).toLowerCase()
        return text === "true" || text === "1" || text === "yes"
    }

    function tabIdFor(row, index) {
        return roleValue(row, ["tabId", "id", "tabIndex", "index"], index)
    }

    function normalizedRow(row, index) {
        var paused = boolValue(roleValue(row, ["paused", "isPaused"], false), false)
        var audible = boolValue(roleValue(row, ["audible", "recentlyAudible"], false), false)
        var playing = boolValue(roleValue(row, ["playing", "isPlaying"], audible && !paused), false)

        return {
            tabId: tabIdFor(row, index),
            title: stringValue(roleValue(row, ["title", "name"], qsTr("Медиа"))),
            url: stringValue(roleValue(row, ["url", "sourceUrl"], "")),
            iconUrl: stringValue(roleValue(row, ["iconUrl", "favicon", "icon"], "")),
            muted: boolValue(roleValue(row, ["muted", "audioMuted"], false), false),
            audible: audible,
            paused: paused,
            playing: playing
        }
    }

    function refresh() {
        arrayTabsModel.clear()
        if (!useArrayModel)
            return

        for (var i = 0; i < mediaTabs.length; ++i)
            arrayTabsModel.append(normalizedRow(mediaTabs[i], i))
    }

    onMediaTabsChanged: refresh()
    Component.onCompleted: refresh()

    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    padding: 0
    implicitWidth: 390

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.standard }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Motion.fast; easing.type: Motion.emphasized }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.instant; easing.type: Motion.exit }
    }

    ListModel {
        id: arrayTabsModel
        dynamicRoles: true
    }

    background: Rectangle {
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.glassStroke
    }

    contentItem: ColumnLayout {
        id: body
        implicitWidth: root.implicitWidth
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s4
            spacing: Theme.s3

            Item {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: Theme.accentSoft
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
                }

                Icon {
                    anchors.centerIn: parent
                    name: "volume-2"
                    size: 18
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Медиа")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Font.DemiBold
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.currentLabel.length > 0
                          ? root.currentLabel
                          : qsTr("Активные вкладки со звуком")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
            }

            GlassButton {
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: Theme.controlMd
                text: qsTr("Пауза всех")
                enabled: mediaList.count > 0
                onClicked: root.requestPauseAll()
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

        ListView {
            id: mediaList

            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(322, Math.max(78, contentHeight)) : 0
            visible: count > 0
            model: root.useArrayModel ? arrayTabsModel : root.mediaTabs
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.s1
            topMargin: Theme.s2
            bottomMargin: Theme.s2
            leftMargin: Theme.s2
            rightMargin: Theme.s2

            ScrollBar.vertical: FilkaScrollBar {
                policy: mediaList.contentHeight > mediaList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: row

                required property int index
                required property var model

                readonly property var tabId: root.tabIdFor(model, index)
                readonly property string tabTitle: root.stringValue(root.roleValue(model, ["title", "name"], qsTr("Медиа")))
                readonly property string tabUrl: root.stringValue(root.roleValue(model, ["url", "sourceUrl"], ""))
                readonly property string tabIcon: root.stringValue(root.roleValue(model, ["iconUrl", "favicon", "icon"], ""))
                readonly property bool muted: root.boolValue(root.roleValue(model, ["muted", "audioMuted"], false), false)
                readonly property bool audible: root.boolValue(root.roleValue(model, ["audible", "recentlyAudible"], false), false)
                readonly property bool paused: root.boolValue(root.roleValue(model, ["paused", "isPaused"], false), false)
                readonly property bool playing: root.boolValue(root.roleValue(model, ["playing", "isPlaying"], audible && !paused), false)
                readonly property bool current: root.boolValue(root.roleValue(model, ["current", "active"], false), false)
                                                || (root.currentUrl.length > 0 && tabUrl === root.currentUrl)
                                                || (root.currentTitle.length > 0 && tabTitle === root.currentTitle)

                width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                height: 72
                x: ListView.view.leftMargin
                radius: Theme.radiusMd
                color: current ? Theme.accentSoft
                               : rowHover.hovered ? Theme.hoverFill : "transparent"
                border.width: activeFocus ? Theme.focusWidth : (current ? 1 : 0)
                border.color: activeFocus ? Theme.focusRing
                                          : current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.36)
                                                    : "transparent"
                activeFocusOnTab: true
                Accessible.role: Accessible.ListItem
                Accessible.name: tabTitle

                HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.requestActivate(row.tabId)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s2
                    spacing: Theme.s3

                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            color: row.playing && !row.muted ? Theme.accentSoft : Theme.glassLow
                            border.width: 1
                            border.color: Theme.glassHairline
                        }

                        Image {
                            id: favicon

                            anchors.fill: parent
                            anchors.margins: 8
                            source: row.tabIcon
                            visible: row.tabIcon.length > 0 && status !== Image.Error
                            sourceSize.width: 36
                            sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: row.tabIcon.length === 0 || favicon.status === Image.Error
                            name: row.muted ? "volume-x" : "volume-2"
                            size: 15
                            color: row.muted ? Theme.textMuted
                                             : row.playing ? Theme.accent : Theme.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: row.tabTitle
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: row.current ? Font.DemiBold : Font.Medium
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.muted ? qsTr("Звук выключен")
                                            : row.playing ? qsTr("Воспроизводится")
                                                          : qsTr("Медиа приостановлено")
                            color: row.muted ? Theme.textMuted
                                             : row.playing ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.tabUrl
                            visible: row.tabUrl.length > 0
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            maximumLineCount: 1
                            elide: Text.ElideMiddle
                        }
                    }

                    IconButton {
                        Layout.preferredWidth: size
                        Layout.preferredHeight: size
                        iconName: row.playing ? "minus" : "rotate-cw"
                        size: Theme.controlSm
                        iconSize: 14
                        tooltip: row.playing ? qsTr("Пауза") : qsTr("Продолжить")
                        Accessible.name: tooltip
                        onClicked: root.requestPlayPause(row.tabId)
                    }

                    IconButton {
                        Layout.preferredWidth: size
                        Layout.preferredHeight: size
                        iconName: row.muted ? "volume-x" : "volume-2"
                        size: Theme.controlSm
                        iconSize: 14
                        active: !row.muted && row.audible
                        tooltip: row.muted ? qsTr("Включить звук") : qsTr("Выключить звук")
                        Accessible.name: tooltip
                        onClicked: root.requestMute(row.tabId, !row.muted)
                    }
                }

                Keys.onReturnPressed: root.requestActivate(row.tabId)
                Keys.onEnterPressed: root.requestActivate(row.tabId)
                Keys.onSpacePressed: root.requestActivate(row.tabId)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            Layout.margins: Theme.s5
            visible: mediaList.count === 0
            spacing: Theme.s3

            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: "volume-2"
                size: 34
                color: Theme.textMuted
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Нет активного медиа")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMd
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Вкладки со звуком появятся здесь.")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
