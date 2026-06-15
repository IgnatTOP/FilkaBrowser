import QtQuick
import QtQuick.Layouts
import Filka

// WelcomeDialog — first-run onboarding. A centered glass card over a dimmed
// backdrop that lets the user pick theme, accent and search engine before
// diving in. Dismissed by "Начать", which flips AppSettings.onboarded.
Item {
    id: root
    anchors.fill: parent
    z: 1000

    // Dimmed backdrop.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.55
        TapHandler {}   // swallow clicks behind the card
    }

    // Entrance.
    opacity: 0
    Component.onCompleted: inAnim.start()
    ParallelAnimation {
        id: inAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Motion.standard }
        NumberAnimation { target: card; property: "scale"; from: 0.94; to: 1; duration: Motion.slow; easing.type: Motion.emphasized }
    }

    GlassPanel {
        id: card
        level: 3
        radius: Theme.radiusXl
        width: Math.min(520, root.width - Theme.s6 * 2)
        height: contentCol.height + Theme.s6 * 2
        anchors.centerIn: parent

        Rectangle {   // opaque base for readability
            anchors.fill: parent
            radius: Theme.radiusXl
            color: Theme.bgRaised
            opacity: 0.96
        }

        ColumnLayout {
            id: contentCol
            width: parent.width - Theme.s6 * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s4

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/qt/qml/Filka/assets/logo.png"
                sourceSize: Qt.size(150, 150)
                width: 76; height: 76
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Добро пожаловать в Filka"
                color: Theme.textPrimary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXl; font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Быстрый браузер с рабочими пространствами, приватностью и аккуратной анимацией. Настроим под вас за пару секунд."
                color: Theme.textSecondary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
            }

            // ---- Theme ----
            Text {
                text: "ТЕМА"; color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold; Layout.topMargin: Theme.s2
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Repeater {
                    model: [ { label: "Светлая", dark: false }, { label: "Тёмная", dark: true } ]
                    delegate: Rectangle {
                        id: themeChip
                        required property var modelData
                        readonly property bool sel: AppSettings.darkMode === modelData.dark
                        Layout.fillWidth: true
                        height: 44
                        radius: Theme.radiusMd
                        color: sel ? Theme.accentSoft : Theme.glassLow
                        border.width: 1; border.color: sel ? Theme.accent : Theme.glassStroke
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Row {
                            anchors.centerIn: parent; spacing: Theme.s2
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: themeChip.modelData.dark ? "moon" : "sun"; size: 15
                                color: themeChip.sel ? Theme.accent : Theme.textSecondary
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: themeChip.modelData.label
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                            }
                        }
                        TapHandler { onTapped: AppSettings.darkMode = themeChip.modelData.dark }
                    }
                }
            }

            // ---- Accent ----
            Text {
                text: "АКЦЕНТ"; color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.DemiBold
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s3
                Repeater {
                    model: ["#2E7CF6", "#8B5CF6", "#22D3EE", "#34D399", "#FBBF24", "#F87171", "#EC4899"]
                    delegate: Rectangle {
                        id: accentSw
                        required property string modelData
                        readonly property bool sel: AppSettings.accentColor.toLowerCase() === modelData.toLowerCase()
                        width: 32; height: 32; radius: 16
                        color: modelData
                        scale: sel ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }
                        border.width: sel ? 2 : 0; border.color: "white"
                        TapHandler { onTapped: AppSettings.accentColor = accentSw.modelData }
                    }
                }
            }

            // ---- Search engine ----
            Text {
                text: "ПОИСК"; color: Theme.textMuted
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Font.DemiBold
            }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.s2
                Repeater {
                    model: AppSettings.searchEngines()
                    delegate: Rectangle {
                        id: engChip
                        required property string modelData
                        readonly property bool sel: AppSettings.searchEngine === modelData
                        width: engName.implicitWidth + Theme.s4; height: 34
                        radius: Theme.radiusPill
                        color: sel ? Theme.accentSoft : Theme.glassLow
                        border.width: 1; border.color: sel ? Theme.accent : Theme.glassStroke
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Text {
                            id: engName
                            anchors.centerIn: parent; text: engChip.modelData
                            color: engChip.sel ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
                        }
                        TapHandler { onTapped: AppSettings.searchEngine = engChip.modelData }
                    }
                }
            }

            // ---- CTA ----
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s3
                height: 48
                radius: Theme.radiusMd
                color: ctaHover.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Text {
                    anchors.centerIn: parent
                    text: "Начать"
                    color: "white"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold
                }
                HoverHandler { id: ctaHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: AppSettings.onboarded = true }
            }
        }
    }
}
