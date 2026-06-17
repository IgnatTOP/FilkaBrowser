pragma Singleton
import QtQuick

// Filka design system — deep-space chrome, dense matte glass and a violet to
// blue brand line. The tokens stay semantic so existing controls inherit the
// premium visual language without local colour forks.
QtObject {
    id: theme

    property bool dark: true

    // ----- Brand palette (fixed, theme-independent reference tokens) -----
    readonly property color obsidian:      "#060912"
    readonly property color plumGray:      "#101522"
    readonly property color titanium:      "#252B38"
    readonly property color frostWhite:    "#F7F8FA"

    // Signature Filka gradient: violet -> lavender -> cool blue.
    readonly property color brandViolet:   "#8B5CF6"
    readonly property color brandLavender: "#C4B5FD"
    readonly property color brandBlue:     "#38BDF8"
    readonly property color brandInk:      "#15112A"

    // ----- Semantic surfaces (resolve against current mode) -----
    readonly property color bgBase:    dark ? obsidian  : "#EEF1F8"
    readonly property color bgSunken:  dark ? "#030611" : "#E2E7F1"
    readonly property color bgRaised:  dark ? plumGray  : frostWhite
    readonly property color surface:   dark ? "#121827" : "#FFFFFF"
    readonly property color surfaceAlt: dark ? "#192033" : "#F1F4FA"
    readonly property color chrome:    dark ? Qt.rgba(0.035, 0.045, 0.075, 0.88) : Qt.rgba(0.97, 0.98, 1, 0.90)
    readonly property color sidebar:   dark ? Qt.rgba(0.025, 0.035, 0.060, 0.78) : Qt.rgba(0.95, 0.97, 1, 0.84)
    readonly property color card:      dark ? Qt.rgba(0.08, 0.10, 0.16, 0.74) : Qt.rgba(1, 1, 1, 0.82)
    readonly property color hoverFill: dark ? Qt.rgba(1, 1, 1, 0.080) : Qt.rgba(0, 0, 0, 0.045)
    readonly property color activeFill: dark ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                                             : Qt.rgba(accent.r, accent.g, accent.b, 0.11)
    readonly property color outline:   dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0.05, 0.08, 0.12, 0.12)

    // Dense matte glass fills. They stay translucent but never look like thin
    // legacy glassmorphism.
    readonly property color glassLow:  dark ? Qt.rgba(0.06, 0.075, 0.12, 0.42) : Qt.rgba(1, 1, 1, 0.54)
    readonly property color glassMed:  dark ? Qt.rgba(0.10, 0.12, 0.18, 0.56) : Qt.rgba(1, 1, 1, 0.68)
    readonly property color glassHigh: dark ? Qt.rgba(0.16, 0.17, 0.24, 0.70) : Qt.rgba(1, 1, 1, 0.84)
    readonly property color glassStroke: outline
    readonly property color glassHairline: dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.070)
    readonly property color glassHighlight: dark ? Qt.rgba(1, 1, 1, 0.115) : Qt.rgba(1, 1, 1, 0.78)

    // ----- Modal / popover surfaces -----
    // Floating dialogs, popovers and menus must stay fully opaque so live web
    // content never bleeds through them. `modalSurface` is a touch lighter than
    // `surface` to read as elevated above the page. `scrim` dims the page behind
    // centered modals; `scrimSoft` is the gentler dim used behind anchored
    // popovers that should not feel fully blocking.
    readonly property color modalSurface: dark ? "#171E30" : "#FFFFFF"
    readonly property color scrim:     dark ? Qt.rgba(0, 0, 0, 0.60) : Qt.rgba(0.06, 0.08, 0.14, 0.34)
    readonly property color scrimSoft: dark ? Qt.rgba(0, 0, 0, 0.36) : Qt.rgba(0.06, 0.08, 0.14, 0.16)

    // ----- Text -----
    readonly property color textPrimary:   dark ? "#F7F8FF" : "#10131B"
    readonly property color textSecondary: dark ? Qt.rgba(0.96, 0.98, 1, 0.70) : Qt.rgba(0.05, 0.08, 0.12, 0.66)
    readonly property color textMuted:      dark ? Qt.rgba(0.96, 0.98, 1, 0.56) : Qt.rgba(0.05, 0.08, 0.12, 0.62)

    // ----- Accent system -----
    // `accent` is user-overridable (synced from AppSettings.accentColor in
    // Main.qml); everything accent-tinted derives from it so a single choice
    // re-themes the whole UI.
    property color accent: brandViolet
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
    readonly property color accentSofter: Qt.rgba(accent.r, accent.g, accent.b, 0.09)
    readonly property color accentForeground: "#05060A"
    readonly property color accentSoftForeground: textPrimary
    readonly property color focusRing: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.90 : 0.86)
    readonly property color positive: "#34D399"
    readonly property color warning:  "#FBBF24"
    readonly property color danger:   "#F87171"

    readonly property var auroraStops: [brandViolet, brandLavender, brandBlue]

    // ----- Shape -----
    readonly property real radiusSm: 8
    readonly property real radiusMd: 12
    readonly property real radiusLg: 16
    readonly property real radiusXl: 22
    readonly property real radiusPill: 999

    // ----- Soft shadow tokens (consumed via DropShadow/MultiEffect) -----
    readonly property color shadowColor: dark ? Qt.rgba(0, 0, 0, 0.52) : Qt.rgba(0.1, 0.15, 0.25, 0.16)
    readonly property real shadowBlur: 34
    readonly property real shadowY: 14

    // ----- Spacing scale (4pt grid) -----
    readonly property real s1: 4
    readonly property real s2: 8
    readonly property real s3: 12
    readonly property real s4: 16
    readonly property real s5: 24
    readonly property real s6: 32
    readonly property real s7: 40

    // ----- Type -----
    readonly property string fontFamily: "sans-serif"
    readonly property real fontSizeXs: 12
    readonly property real fontSizeSm: 14
    readonly property real fontSizeMd: 16
    readonly property real fontSizeLg: 19
    readonly property real fontSizeXl: 23
    readonly property real fontSizeDisplay: 48

    // ----- Control metrics -----
    readonly property real controlSm: 30
    readonly property real controlMd: 34
    readonly property real controlLg: 42
    readonly property real toolbarHeight: 50
    readonly property real focusWidth: 2

    // ----- Start-page wallpaper helpers -----
    readonly property color wallpaperScrimTop:    Qt.rgba(0.02, 0.025, 0.045, 0.18)
    readonly property color wallpaperScrimBottom: Qt.rgba(0.01, 0.015, 0.030, 0.58)
    readonly property color wallpaperSidebar:     Qt.rgba(0.02, 0.03, 0.055, 0.76)

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
