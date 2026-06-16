import QtQuick
import Filka

// Favicon — a rounded badge showing a site's real favicon, fetched by host. If
// the icon can't be loaded (offline, no favicon) it falls back to a single
// letter on a neutral surface, so the badge is never empty. Used by the start
// page speed-dial and the recent / bookmarks cards.
Rectangle {
    id: root

    property string host: ""
    property string fallbackText: ""
    property color backdrop: Theme.glassMed

    radius: Theme.radiusSm
    color: backdrop

    Image {
        id: img
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.62)
        height: width
        // DuckDuckGo returns the icon directly (HTTP 200, no redirect), which
        // QML's Image loader handles reliably; the Google s2 endpoint answers
        // with a 3xx redirect that the loader does not follow.
        source: root.host ? "https://icons.duckduckgo.com/ip3/" + root.host + ".ico" : ""
        sourceSize: Qt.size(64, 64)
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: root.fallbackText
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(parent.height * 0.42)
        font.weight: Font.DemiBold
    }
}
