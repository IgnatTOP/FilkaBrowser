import QtQuick
import QtQuick.Controls.Basic
import Filka

// AddressBar — glass pill that doubles as URL input and search box. Shows a
// security glyph on the left and a thin loading bar along the bottom edge.
FocusScope {
    id: root

    property string displayUrl: ""
    property bool secure: false
    property bool loading: false
    property real progress: 0          // 0..1
    signal navigate(string text)       // emitted with raw user text

    implicitHeight: 38

    // Pull keyboard focus into the input and pre-select its text, so the user
    // can immediately type a new address (Ctrl+L / Ctrl+K).
    function focusInput() {
        field.forceActiveFocus()
        field.selectAll()
    }

    // Decide whether the input is a URL or a search query.
    function resolve(text) {
        var t = text.trim()
        if (t.length === 0) return ""
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t)) return t        // has scheme
        if (/^(localhost|[0-9.]+)(:[0-9]+)?(\/.*)?$/i.test(t)) return "http://" + t
        if (!/\s/.test(t) && /^[^\s]+\.[^\s]{2,}/.test(t)) return "https://" + t
        return AppSettings.searchUrl(t)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: field.activeFocus ? Theme.glassHigh : Theme.glassLow
        border.width: 1
        border.color: field.activeFocus ? Theme.accent : Theme.glassStroke
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        Icon {  // security indicator
            id: lock
            anchors { left: parent.left; leftMargin: Theme.s4; verticalCenter: parent.verticalCenter }
            name: root.secure ? "lock" : "globe"
            size: 15
            color: root.secure ? Theme.positive : Theme.textMuted
        }

        TextField {
            id: field
            anchors { left: lock.right; right: parent.right; verticalCenter: parent.verticalCenter
                      leftMargin: Theme.s2; rightMargin: Theme.s4 }
            focus: true
            text: root.displayUrl
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: "Search the web or enter an address"
            placeholderTextColor: Theme.textMuted
            background: null
            Accessible.name: "Address bar"

            onActiveFocusChanged: if (activeFocus) selectAll()
            onAccepted: {
                var url = root.resolve(text)
                if (url.length) root.navigate(url)
                focus = false
            }
            Keys.onEscapePressed: { text = root.displayUrl; focus = false }
        }

        // Thin loading progress along the bottom.
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 2; bottomMargin: 2 }
            height: 2
            radius: 1
            width: (parent.width - 4) * root.progress
            visible: root.loading
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.electricBlue }
                GradientStop { position: 1.0; color: Theme.cyan }
            }
            Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Motion.standard } }
        }
    }
}
