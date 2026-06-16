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
        opacity: Theme.dark ? 0.50 : 0.28
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
        level: 2
        radius: Theme.radiusLg
        width: Math.min(540, root.width - Theme.s5 * 2)
        height: contentCol.height + Theme.s6 * 2
        anchors.centerIn: parent

        Rectangle {   // opaque base for readability
            anchors.fill: parent
            radius: Theme.radiusLg
            color: Theme.surface
            opacity: 0.98
        }

        ColumnLayout {
            id: contentCol
            width: Math.max(260, parent.width - Theme.s6 * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s4

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/qt/qml/Filka/assets/logo.png"
                sourceSize: Qt.size(150, 150)
                Layout.preferredWidth: 76; Layout.preferredHeight: 76
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Добро пожаловать в Filka")
                color: Theme.textPrimary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Быстрый браузер с рабочими пространствами, приватностью и аккуратной анимацией. Настроим под вас за пару секунд.")
                color: Theme.textSecondary
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm
            }

            // ---- Theme ----
            SectionLabel { text: qsTr("Тема"); Layout.topMargin: Theme.s2; color: Theme.textMuted }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Repeater {
                    model: [ { label: qsTr("Светлая"), dark: false }, { label: qsTr("Тёмная"), dark: true } ]
                    delegate: Chip {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: Theme.radiusMd
                        fontSize: Theme.fontSizeSm
                        iconSize: 15
                        iconName: modelData.dark ? "moon" : "sun"
                        label: modelData.label
                        selected: AppSettings.darkMode === modelData.dark
                        onClicked: AppSettings.darkMode = modelData.dark
                    }
                }
            }

            // ---- Accent ----
            SectionLabel { text: qsTr("Акцент"); color: Theme.textMuted }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s3
                Repeater {
                    model: ["#FF6A4D", "#FFA63D", "#FF5C7A", "#9B5CF6", "#22D3EE", "#34D399", "#2E7CF6"]
                    delegate: AccentSwatch {
                        required property string modelData
                        width: 32; height: 32
                        swatchColor: modelData
                        selected: AppSettings.accentColor.toLowerCase() === modelData.toLowerCase()
                        onClicked: AppSettings.accentColor = modelData
                    }
                }
            }

            // ---- Search engine ----
            SectionLabel { text: qsTr("Поиск"); color: Theme.textMuted }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.s2
                Repeater {
                    model: AppSettings.searchEngines()
                    delegate: Chip {
                        required property string modelData
                        height: 34
                        fontSize: Theme.fontSizeSm
                        label: modelData
                        selected: AppSettings.searchEngine === modelData
                        onClicked: AppSettings.searchEngine = modelData
                    }
                }
            }

            // ---- CTA ----
            GlassButton {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s3
                implicitHeight: 48
                accentVariant: true
                text: qsTr("Начать")
                font.pixelSize: Theme.fontSizeMd
                font.weight: Font.DemiBold
                onClicked: AppSettings.onboarded = true
            }
        }
    }
}
