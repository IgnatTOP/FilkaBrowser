pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

Item {
    id: root

    signal navigate(string text)
    signal openPanel(string panel)

    property bool privateMode: false
    property string workspaceName: ""
    property int tabCount: 0
    readonly property var _loc: Qt.locale("ru_RU")
    property string timeText: ""
    property string dateText: ""
    property string greeting: ""
    property int editIndex: -1
    property string linkTitleError: ""
    property string linkUrlError: ""
    property var recentPages: []
    readonly property bool compact: width < 820
    readonly property real contentWidth: Math.min(760, Math.max(360, width - Theme.s7 * 2))
    readonly property int visibleDownloadCount: privateMode ? DownloadModel.count : DownloadModel.publicCount

    component GlassCard: Rectangle {
        radius: Theme.radiusLg
        color: Theme.glassMed
        border.width: 1
        border.color: Theme.glassStroke
    }

    function hostOf(u) {
        var s = ("" + u).replace(/^[a-z]+:\/\//i, "").replace(/^www\./i, "")
        var slash = s.indexOf("/")
        return slash >= 0 ? s.slice(0, slash) : s
    }

    function initials(text) {
        var clean = ("" + text).trim()
        return clean.length > 0 ? clean.charAt(0).toUpperCase() : "F"
    }

    function refreshClock() {
        const now = new Date()
        timeText = now.toLocaleTimeString(root._loc, "HH:mm")
        const d = now.toLocaleDateString(root._loc, "dddd, d MMMM")
        dateText = d.charAt(0).toUpperCase() + d.slice(1)
        const h = now.getHours()
        greeting = h < 5  ? qsTr("Доброй ночи")
                 : h < 12 ? qsTr("Доброе утро")
                 : h < 18 ? qsTr("Добрый день")
                 : h < 23 ? qsTr("Добрый вечер")
                          : qsTr("Доброй ночи")
    }

    function relTime(dt) {
        if (!dt || isNaN(dt.getTime()))
            return ""
        var diff = (Date.now() - dt.getTime()) / 1000
        if (diff < 60)
            return qsTr("только что")
        if (diff < 3600)
            return qsTr("%1 мин назад").arg(Math.floor(diff / 60))
        if (diff < 86400)
            return qsTr("%1 ч назад").arg(Math.floor(diff / 3600))
        if (diff < 172800)
            return qsTr("вчера")
        return Qt.formatDateTime(dt, "d MMM")
    }

    function reloadRecent() {
        recentPages = HistoryModel.recent(3)
    }

    function openLinkEditor(index, title, url) {
        editIndex = index
        linkTitleError = ""
        linkUrlError = ""
        linkTitle.text = title
        linkUrl.text = url
        validateLinkEditorUrl()
        editor.open()
        linkTitle.forceActiveFocus()
        linkTitle.selectAll()
    }

    function normalizedLinkEditorUrl() {
        var rawUrl = linkUrl.text.trim()
        if (rawUrl.length === 0) {
            linkUrlError = qsTr("Введите адрес сайта")
            return ""
        }

        var url = /^[a-z][a-z0-9+.-]*:/i.test(rawUrl) ? rawUrl : "https://" + rawUrl
        try {
            var parsed = new URL(url)
            if ((parsed.protocol !== "http:" && parsed.protocol !== "https:") || parsed.hostname.length === 0) {
                linkUrlError = qsTr("Введите адрес сайта")
                return ""
            }
            linkUrlError = ""
            return parsed.href
        } catch (e) {
            linkUrlError = qsTr("Введите адрес сайта")
            return ""
        }
    }

    function validateLinkEditorUrl() {
        return normalizedLinkEditorUrl().length > 0
    }

    function saveLinkEditor() {
        var title = linkTitle.text.trim()
        var url = normalizedLinkEditorUrl()
        if (url.length === 0)
            return
        if (editIndex >= 0)
            QuickLinkModel.update(editIndex, title, url)
        else
            QuickLinkModel.add(title, url)
        editor.close()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refreshClock()
    }

    Component.onCompleted: {
        refreshClock()
        reloadRecent()
        intro.restart()
    }
    onVisibleChanged: if (visible) {
        reloadRecent()
        intro.restart()
    }

    Connections {
        target: HistoryModel
        function onCountChanged() { root.reloadRecent() }
    }

    Row {
        id: topActions
        z: 30
        anchors { top: parent.top; right: parent.right; topMargin: Theme.s5; rightMargin: Theme.s5 }
        spacing: Theme.s2
        opacity: 0

        GlassCard {
            width: weatherRow.implicitWidth + Theme.s4
            height: 34
            radius: Theme.radiusPill
            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: 7
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "sun"; size: 15; color: Theme.brandLavender }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("21°C  Барселона")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.Medium
                }
            }
        }

        IconButton {
            iconName: "download"
            size: 34
            iconSize: 16
            Accessible.name: qsTr("Загрузки")
            onClicked: root.openPanel("downloads")
        }
        IconButton {
            iconName: "history"
            size: 34
            iconSize: 16
            Accessible.name: qsTr("История")
            onClicked: root.openPanel("history")
        }
        IconButton {
            iconName: "settings"
            size: 34
            iconSize: 16
            Accessible.name: qsTr("Настройки")
            onClicked: root.openPanel("settings")
        }
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, stage.implicitHeight + Theme.s7 * 2)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: stage
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(90, (scroller.height - implicitHeight) * 0.42)
            width: root.contentWidth
            spacing: Theme.s4
            opacity: 0
            scale: 0.985

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Text {
                    Layout.fillWidth: true
                    text: qsTr("%1, %2").arg(root.greeting).arg(AppSettings.displayName)
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 32 : 44
                    font.weight: Font.Light
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }

                Text {
                    Layout.fillWidth: true
                    text: AppSettings.homeSubtitle
                    color: Theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
            }

            GlassCard {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(660, stage.width)
                Layout.preferredHeight: 62
                radius: Theme.radiusPill
                color: search.activeFocus ? Theme.glassHigh : Theme.glassMed
                border.color: search.activeFocus ? Theme.focusRing : Qt.rgba(1, 1, 1, 0.16)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Icon {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: Theme.s5; verticalCenter: parent.verticalCenter }
                    name: "search"
                    size: 24
                    color: search.activeFocus ? Theme.brandLavender : Theme.textSecondary
                }

                TextField {
                    id: search
                    anchors { left: searchIcon.right; right: goBtn.left; verticalCenter: parent.verticalCenter
                              leftMargin: Theme.s4; rightMargin: Theme.s3 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    selectByMouse: true
                    background: null
                    placeholderText: qsTr("Поиск в интернете или введите URL")
                    placeholderTextColor: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.48)
                    Accessible.name: qsTr("Поиск или адрес")
                    onAccepted: {
                        if (text.trim().length) {
                            root.navigate(text)
                            text = ""
                        }
                    }
                }

                IconButton {
                    id: goBtn
                    anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    iconName: "chevron-right"
                    size: 40
                    iconSize: 20
                    active: search.text.trim().length > 0
                    opacity: search.text.trim().length > 0 ? 1 : 0.55
                    Accessible.name: qsTr("Перейти")
                    onClicked: {
                        if (search.text.trim().length) {
                            root.navigate(search.text)
                            search.text = ""
                        }
                    }
                }
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(630, stage.width)
                columns: root.compact ? 3 : 5
                columnSpacing: Theme.s3
                rowSpacing: Theme.s3

                Repeater {
                    model: QuickLinkModel
                    delegate: Item {
                        id: tileWrap
                        required property int index
                        required property string title
                        required property string url
                        required property string host
                        Layout.preferredWidth: root.compact ? 88 : 92
                        Layout.preferredHeight: 112

                        GlassCard {
                            id: tile
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: 88
                            radius: Theme.radiusLg
                            color: tileHover.hovered ? Theme.glassHigh : Theme.glassMed
                            border.width: tile.activeFocus ? Theme.focusWidth : 1
                            border.color: tile.activeFocus ? Theme.focusRing : Qt.rgba(1, 1, 1, 0.15)
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: tileWrap.title
                            scale: tileTap.pressed ? 0.96 : (tileHover.hovered ? 1.035 : 1.0)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }

                            Favicon {
                                id: favicon
                                anchors.centerIn: parent
                                width: 34
                                height: 34
                                radius: Theme.radiusMd
                                host: tileWrap.host
                                fallbackText: root.initials(tileWrap.title)
                            }

                            Row {
                                anchors { right: parent.right; top: parent.top; margins: 5 }
                                spacing: 1
                                opacity: tileHover.hovered || tile.activeFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                                IconButton {
                                    iconName: "settings"
                                    size: 24
                                    iconSize: 12
                                    Accessible.name: qsTr("Редактировать быструю ссылку")
                                    onClicked: root.openLinkEditor(tileWrap.index, tileWrap.title, tileWrap.url)
                                }
                                IconButton {
                                    iconName: "x"
                                    size: 24
                                    iconSize: 12
                                    Accessible.name: qsTr("Удалить быструю ссылку")
                                    onClicked: QuickLinkModel.remove(tileWrap.index)
                                }
                            }

                            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { id: tileTap; onTapped: root.navigate(tileWrap.url) }
                            Keys.onReturnPressed: root.navigate(tileWrap.url)
                            Keys.onEnterPressed: root.navigate(tileWrap.url)
                            Keys.onSpacePressed: root.navigate(tileWrap.url)
                        }

                        Text {
                            anchors { left: parent.left; right: parent.right; top: tile.bottom; topMargin: Theme.s2 }
                            text: tileWrap.title
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    id: addWrap
                    Layout.preferredWidth: root.compact ? 88 : 92
                    Layout.preferredHeight: 112

                    GlassCard {
                        id: addTile
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 88
                        radius: Theme.radiusLg
                        color: addHover.hovered ? Theme.glassHigh : Theme.glassLow
                        border.width: activeFocus ? Theme.focusWidth : 1
                        border.color: activeFocus ? Theme.focusRing : Qt.rgba(1, 1, 1, 0.13)
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Добавить быструю ссылку")
                        scale: addTap.pressed ? 0.96 : (addHover.hovered ? 1.035 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.emphasized } }

                        Icon {
                            anchors.centerIn: parent
                            name: "plus"
                            size: 30
                            color: addHover.hovered ? Theme.textPrimary : Theme.textSecondary
                        }
                        HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: addTap; onTapped: root.openLinkEditor(-1, "", "") }
                        Keys.onReturnPressed: root.openLinkEditor(-1, "", "")
                        Keys.onEnterPressed: root.openLinkEditor(-1, "", "")
                        Keys.onSpacePressed: root.openLinkEditor(-1, "", "")
                    }

                    Text {
                        anchors { left: parent.left; right: parent.right; top: addTile.bottom; topMargin: Theme.s2 }
                        text: qsTr("Добавить")
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.Medium
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s2
                spacing: Theme.s3
                visible: !root.compact && AppSettings.homeSmartCards

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s3

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 78
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.s4
                            spacing: Theme.s3
                            Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; name: "zap"; size: 20; color: Theme.brandBlue }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: root.workspaceName.length > 0 ? root.workspaceName : qsTr("Рабочее пространство")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 %2 открыто").arg(root.tabCount).arg(Theme.plural(root.tabCount, qsTr("вкладка"), qsTr("вкладки"), qsTr("вкладок")))
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 78
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Открыть список загрузок")
                        Keys.onReturnPressed: root.openPanel("downloads")
                        Keys.onEnterPressed: root.openPanel("downloads")
                        Keys.onSpacePressed: root.openPanel("downloads")
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.s4
                            spacing: Theme.s3
                            Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; name: "history"; size: 20; color: Theme.brandLavender }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: root.dateText + " · " + root.timeText
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("История, загрузки и перевод в один клик")
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 78
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.s4
                            spacing: Theme.s3
                            Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; name: "download"; size: 20; color: Theme.positive }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: root.visibleDownloadCount > 0 ? qsTr("Загрузки: %1").arg(root.visibleDownloadCount) : qsTr("Загрузки")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.visibleDownloadCount > 0 ? qsTr("Открыть список загрузок") : qsTr("Файлы появятся здесь после сохранения")
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                }
                            }
                            TapHandler { onTapped: root.openPanel("downloads") }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                GlassCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.recentPages.length > 0 ? 132 : 78

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.s4
                        spacing: Theme.s3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.s2
                            Icon { Layout.preferredWidth: 18; Layout.preferredHeight: 18; name: "history"; size: 18; color: Theme.brandLavender }
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Продолжить")
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: HistoryModel.count + " " + Theme.plural(HistoryModel.count, qsTr("запись"), qsTr("записи"), qsTr("записей"))
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.recentPages.length === 0
                            text: qsTr("После навигации здесь появятся последние страницы.")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.recentPages.length > 0
                            spacing: Theme.s2

                            Repeater {
                                model: root.recentPages
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    radius: Theme.radiusMd
                                    color: recentHover.hovered ? Theme.glassHigh : Theme.glassLow
                                    border.width: activeFocus ? Theme.focusWidth : 1
                                    border.color: activeFocus ? Theme.focusRing : Theme.glassStroke
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.title

                                    Column {
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                                  leftMargin: Theme.s3; rightMargin: Theme.s3 }
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: root.hostOf(modelData.url) + " · " + root.relTime(modelData.lastVisit)
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            elide: Text.ElideRight
                                        }
                                    }

                                    HoverHandler { id: recentHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.navigate(modelData.url) }
                                    Keys.onReturnPressed: root.navigate(modelData.url)
                                    Keys.onEnterPressed: root.navigate(modelData.url)
                                    Keys.onSpacePressed: root.navigate(modelData.url)
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: intro
        running: false
        OpacityAnimator { target: stage; from: 0; to: 1; duration: Motion.slow; easing.type: Motion.standard }
        ScaleAnimator { target: stage; from: 0.985; to: 1.0; duration: Motion.slow; easing.type: Motion.emphasized }
        OpacityAnimator { target: topActions; from: 0; to: 1; duration: Motion.slow; easing.type: Motion.standard }
    }

    Popup {
        id: editor
        modal: true
        focus: true
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(440, root.width - Theme.s6)
        padding: Theme.s4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: Theme.radiusLg
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline
        }

        contentItem: ColumnLayout {
            spacing: Theme.s3
            Text {
                Layout.fillWidth: true
                text: root.editIndex >= 0 ? qsTr("Редактировать ссылку") : qsTr("Новая быстрая ссылка")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMd
                font.weight: Font.DemiBold
            }
            TextField {
                id: linkTitle
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                placeholderText: qsTr("Название")
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: linkTitle.activeFocus ? Theme.surfaceAlt : Theme.card
                    border.width: 1
                    border.color: linkTitle.activeFocus ? Theme.accent : Theme.outline
                }
            }
            TextField {
                id: linkUrl
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                selectByMouse: true
                placeholderText: qsTr("https://example.com")
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    radius: Theme.radiusMd
                    color: linkUrl.activeFocus ? Theme.surfaceAlt : Theme.card
                    border.width: 1
                    border.color: root.linkUrlError.length > 0 ? Theme.danger
                                : linkUrl.activeFocus ? Theme.accent
                                                      : Theme.outline
                }
                onTextChanged: root.validateLinkEditorUrl()
                onAccepted: root.saveLinkEditor()
            }
            Text {
                Layout.fillWidth: true
                visible: root.linkUrlError.length > 0
                text: root.linkUrlError
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXs
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Item { Layout.fillWidth: true }
                Pill {
                    implicitHeight: 34
                    accessibleName: qsTr("Отменить редактирование быстрой ссылки")
                    onClicked: editor.close()
                    Text {
                        text: qsTr("Отмена")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Pill {
                    id: saveLinkButton
                    implicitHeight: 34
                    accessibleName: qsTr("Сохранить быструю ссылку")
                    interactive: root.linkUrlError.length === 0 && linkUrl.text.trim().length > 0
                    opacity: interactive ? 1 : 0.45
                    fillColor: interactive ? Theme.accent : Theme.surfaceAlt
                    strokeWidth: interactive ? 0 : 1
                    onClicked: root.saveLinkEditor()
                    Text {
                        text: qsTr("Сохранить")
                        color: saveLinkButton.interactive ? Theme.accentForeground : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
