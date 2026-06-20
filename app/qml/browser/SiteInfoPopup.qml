pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Filka

FocusScope {
    id: root

    required property var browser
    required property ShellState shell
    property bool open: false

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    z: 490
    focus: open
    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.standard } }

    function hostOf(url) {
        var s = ("" + url).replace(/^[a-z]+:\/\//i, "").replace(/^www\./i, "")
        var slash = s.indexOf("/")
        return slash >= 0 ? s.slice(0, slash) : s
    }
    function permissions() { return SiteDataHelper.permissionsForOrigin(browser.profile, browser.currentUrl) }
    function storageLabel() {
        return SiteDataHelper.isOffTheRecord(browser.profile)
                ? qsTr("Cookie и storage доступны только в приватной сессии")
                : qsTr("Cookie и local/session storage этого origin")
    }
    function clearSiteStorage() {
        if (browser.activeView) {
            browser.activeView.runJavaScript("try{localStorage.clear();sessionStorage.clear();if(window.indexedDB&&indexedDB.databases){indexedDB.databases().then(dbs=>dbs.forEach(db=>db.name&&indexedDB.deleteDatabase(db.name)));}}catch(e){}")
        }
    }
    function close() { shell.closeOverlays() }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrimSoft
        TapHandler { onTapped: root.close() }
    }

    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: Theme.s5 }
        width: Math.min(460, parent.width - Theme.s6)
        height: Math.min(content.implicitHeight + Theme.s4 * 2, parent.height - Theme.s8)
        radius: Theme.radiusLg
        color: Theme.modalSurface
        border.width: 1
        border.color: Theme.outline
        clip: true

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s4 }
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                Icon { Layout.preferredWidth: 28; Layout.preferredHeight: 28; name: browser.isSecure ? "lock" : "globe"; size: 22; color: browser.isSecure ? Theme.positive : Theme.warning }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { Layout.fillWidth: true; text: root.hostOf(browser.currentUrl); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: SiteDataHelper.originForUrl(browser.currentUrl); color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; elide: Text.ElideMiddle }
                }
                IconButton { Layout.preferredWidth: 28; Layout.preferredHeight: 28; iconName: "x"; size: 28; iconSize: 13; Accessible.name: qsTr("Закрыть"); onClicked: root.close() }
            }

            Text { Layout.fillWidth: true; visible: browser.privateMode; text: qsTr("Приватный режим: данные будут удалены при закрытии приватных окон."); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; wrapMode: Text.WordWrap }

            SectionLabel { text: qsTr("Соединение") }
            Text { Layout.fillWidth: true; text: browser.isSecure ? qsTr("HTTPS: защищённое соединение") : qsTr("Не HTTPS: соединение не защищено"); color: browser.isSecure ? Theme.positive : Theme.warning; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; wrapMode: Text.WordWrap }

            SectionLabel { text: qsTr("Permissions этого сайта") }
            Repeater {
                model: root.permissions()
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: modelData.name; color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; elide: Text.ElideRight }
                    Text { text: modelData.state; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs }
                }
            }
            Text { Layout.fillWidth: true; visible: root.permissions().length === 0; text: qsTr("Для этого origin нет сохранённых разрешений."); color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; wrapMode: Text.WordWrap }

            SectionLabel { text: qsTr("Cookies / Storage этого сайта") }
            Text { Layout.fillWidth: true; text: root.storageLabel(); color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; wrapMode: Text.WordWrap }

            SectionLabel { text: qsTr("Adblock для этого сайта") }
            Text { Layout.fillWidth: true; text: AdBlockManager.enabled ? (AdBlockManager.isSiteAllowed(browser.currentUrl) ? qsTr("Выключен для этого сайта") : qsTr("Включён для этого сайта (%1, правил: %2)").arg(AdBlockManager.mode).arg(AdBlockManager.rulesCount)) : qsTr("Глобально выключен"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; wrapMode: Text.WordWrap }

            SectionLabel { text: qsTr("Zoom этой вкладки") }
            Text { Layout.fillWidth: true; text: qsTr("Текущий масштаб: %1%").arg(Math.round(browser.zoomFactor * 100)); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outline }

            RowLayout {
                Layout.fillWidth: true; spacing: Theme.s2
                Pill { Layout.fillWidth: true; implicitHeight: 34; accessibleName: qsTr("Сбросить масштаб этой вкладки"); onClicked: browser.resetZoom(); Text { text: qsTr("Сбросить zoom вкладки"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs } }
                Pill { Layout.fillWidth: true; implicitHeight: 34; accessibleName: qsTr("Копировать URL"); onClicked: PageTranslator.copyToClipboard(browser.currentUrl); Text { text: qsTr("Копировать URL"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs } }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.s2
                Pill { Layout.fillWidth: true; implicitHeight: 34; accessibleName: qsTr("Сбросить разрешения этого сайта"); onClicked: SiteDataHelper.clearPermissionsForOrigin(browser.profile, browser.currentUrl); Text { text: qsTr("Сбросить permissions сайта"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs } }
                Pill { Layout.fillWidth: true; implicitHeight: 34; accessibleName: qsTr("Очистить cookie этого сайта"); onClicked: SiteDataHelper.clearCookiesForOrigin(browser.profile, browser.currentUrl); Text { text: qsTr("Очистить cookie сайта"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs } }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.s2
                Pill { Layout.fillWidth: true; implicitHeight: 34; accessibleName: qsTr("Очистить storage текущего сайта"); onClicked: root.clearSiteStorage(); Text { text: qsTr("Очистить storage сайта"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs } }
                Pill { Layout.fillWidth: true; implicitHeight: 34; accessibleName: qsTr("Переключить adblock для текущего сайта"); onClicked: AdBlockManager.setSiteAllowed(browser.currentUrl, !AdBlockManager.isSiteAllowed(browser.currentUrl)); Text { text: AdBlockManager.isSiteAllowed(browser.currentUrl) ? qsTr("Включить adblock сайта") : qsTr("Выключить adblock сайта"); color: Theme.textPrimary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs } }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
