import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

// StartPage — Filka's welcome / new-tab surface. Shown (in place of a web view)
// whenever the active tab sits on the "about:blank" home sentinel. Floats over
// the animated aurora backdrop with a big brand mark, a search/URL field and a
// grid of quick links. Emits `navigate` with raw user text or a URL.
Item {
    id: root
    signal navigate(string text)

    // Curated quick links. Colour is the tile accent; label's first letter is
    // the glyph (favicon-free, fully offline, on-brand).
    readonly property var quickLinks: [
        { name: "YouTube",   url: "https://youtube.com",        color: "#FF0000" },
        { name: "GitHub",    url: "https://github.com",         color: "#6E5494" },
        { name: "Wikipedia", url: "https://wikipedia.org",      color: "#3366CC" },
        { name: "Reddit",    url: "https://reddit.com",         color: "#FF4500" },
        { name: "Yandex",    url: "https://yandex.ru",          color: "#FC3F1D" },
        { name: "ChatGPT",   url: "https://chatgpt.com",        color: "#10A37F" },
        { name: "Twitch",    url: "https://twitch.tv",          color: "#9146FF" },
        { name: "Maps",      url: "https://maps.google.com",    color: "#34A853" },
    ]

    // Soft fade/rise entrance whenever the start page appears.
    opacity: 0
    Component.onCompleted: showAnim.start()
    onVisibleChanged: if (visible) { riseY.from = 18; opacity = 0; showAnim.restart() }
    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Motion.slow; easing.type: Motion.standard }
        NumberAnimation { id: riseY; target: stack; property: "anchors.verticalCenterOffset"; from: 18; to: 0; duration: Motion.slow; easing.type: Motion.emphasized }
    }

    ColumnLayout {
        id: stack
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(680, parent.width - Theme.s6 * 2)
        spacing: Theme.s5

        // ---- Brand mark ----
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/qt/qml/Filka/assets/logo.png"
            sourceSize: Qt.size(220, 220)
            width: 96; height: 96
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Filka"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 40
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Theme.s4
            text: "Ищите в сети или введите адрес"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMd
        }

        // ---- Search / address field ----
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s2
            height: 56
            radius: Theme.radiusPill
            color: search.activeFocus ? Theme.glassHigh : Theme.glassMed
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.glassStroke
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            Icon {
                id: searchIcon
                anchors { left: parent.left; leftMargin: Theme.s4; verticalCenter: parent.verticalCenter }
                name: "search"; size: 18; color: Theme.textMuted
            }
            TextField {
                id: search
                anchors { left: searchIcon.right; right: parent.right; verticalCenter: parent.verticalCenter
                          leftMargin: Theme.s3; rightMargin: Theme.s4 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                selectByMouse: true
                background: null
                placeholderText: "Поиск или адрес сайта"
                placeholderTextColor: Theme.textMuted
                onAccepted: { if (text.trim().length) { root.navigate(text); text = "" } }
            }
        }

        // ---- Quick links ----
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s3
            columns: Math.max(4, Math.min(8, Math.floor(width / 96)))
            rowSpacing: Theme.s3
            columnSpacing: Theme.s3

            Repeater {
                model: root.quickLinks
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 84
                    implicitHeight: 92

                    // Staggered entrance animation.
                    opacity: 0
                    y: 12
                    Component.onCompleted: tileEntrance.start()
                    SequentialAnimation {
                        id: tileEntrance
                        PauseAnimation { duration: 80 + tile.index * 50 }
                        ParallelAnimation {
                            NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 300; easing.type: Motion.standard }
                            NumberAnimation { target: tile; property: "y"; to: 0; duration: 350; easing.type: Motion.emphasized }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.s2

                        Rectangle {
                            id: badge
                            width: 60; height: 60; radius: Theme.radiusLg
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: tile.modelData.color
                            scale: tileHover.hovered ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }

                            Rectangle {   // subtle top sheen
                                anchors.fill: parent
                                radius: parent.radius
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: tile.modelData.name.charAt(0)
                                color: "white"
                                font.family: Theme.fontFamily
                                font.pixelSize: 26
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.name
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            elide: Text.ElideRight
                            width: tile.implicitWidth
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.navigate(tile.modelData.url) }
                }
            }
        }
    }
}
