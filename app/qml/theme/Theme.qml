pragma Singleton
import QtQuick

// Filka design system — single source of truth for colors, depth, radii and
// typography. Liquid Glass aesthetic: graphite/titanium neutrals with electric
// blue / aurora purple / cyan accents. Flip `dark` to switch Light/Dark.
QtObject {
    id: theme

    property bool dark: true

    // ----- Brand palette (fixed, theme-independent reference tokens) -----
    readonly property color graphiteBlack: "#0B0D10"
    readonly property color deepSpaceGray: "#15181D"
    readonly property color titanium:      "#2A2F37"
    readonly property color frostWhite:    "#F4F7FB"

    readonly property color electricBlue:  "#2E7CF6"
    readonly property color auroraPurple:  "#8B5CF6"
    readonly property color cyan:          "#22D3EE"

    // ----- Semantic surfaces (resolve against current mode) -----
    readonly property color bgBase:    dark ? graphiteBlack : "#EEF1F6"
    readonly property color bgSunken:  dark ? "#070809"     : "#E2E7EF"
    readonly property color bgRaised:  dark ? deepSpaceGray : frostWhite

    // Glass fills — translucent so backdrop blur shows depth layers.
    readonly property color glassLow:  dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color glassMed:  dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.68)
    readonly property color glassHigh: dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.80)
    readonly property color glassStroke: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.9)
    readonly property color glassHairline: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)

    // ----- Text -----
    readonly property color textPrimary:   dark ? "#F4F7FB" : "#0B0D10"
    readonly property color textSecondary: dark ? Qt.rgba(0.96, 0.98, 1, 0.62) : Qt.rgba(0, 0, 0, 0.6)
    readonly property color textMuted:      dark ? Qt.rgba(0.96, 0.98, 1, 0.38) : Qt.rgba(0, 0, 0, 0.4)

    // ----- Accent system -----
    // `accent` is user-overridable (synced from AppSettings.accentColor in
    // Main.qml); everything accent-tinted derives from it so a single choice
    // re-themes the whole UI.
    property color accent: electricBlue
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
    readonly property color positive: "#34D399"
    readonly property color warning:  "#FBBF24"
    readonly property color danger:   "#F87171"

    // Aurora accent gradient used for highlights, focus rings, AI/VPN flair.
    readonly property var auroraStops: [electricBlue, auroraPurple, cyan]

    // ----- Shape -----
    readonly property real radiusSm: 8
    readonly property real radiusMd: 14
    readonly property real radiusLg: 20
    readonly property real radiusXl: 28
    readonly property real radiusPill: 999

    // ----- Soft shadow tokens (consumed via DropShadow/MultiEffect) -----
    readonly property color shadowColor: dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0.1, 0.15, 0.25, 0.20)
    readonly property real shadowBlur: 48
    readonly property real shadowY: 18

    // ----- Spacing scale (4pt grid) -----
    readonly property real s1: 4
    readonly property real s2: 8
    readonly property real s3: 12
    readonly property real s4: 16
    readonly property real s5: 24
    readonly property real s6: 32

    // ----- Type -----
    readonly property string fontFamily: "sans-serif"
    readonly property real fontSizeXs: 11
    readonly property real fontSizeSm: 13
    readonly property real fontSizeMd: 14
    readonly property real fontSizeLg: 17
    readonly property real fontSizeXl: 22

    function toggleMode() { dark = !dark }

    // Russian plural picker: returns one/few/many for the given count
    // (e.g. plural(n, "запись", "записи", "записей")).
    function plural(n, one, few, many) {
        var m10 = n % 10
        var m100 = n % 100
        if (m10 === 1 && m100 !== 11) return one
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few
        return many
    }
}
