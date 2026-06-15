pragma Singleton
import QtQuick

// Filka motion system — one source of truth for animation timing and easing so
// every transition feels like the same product. Durations are tuned to stay
// smooth from 60Hz up to 240Hz (frame-independent, GPU-driven).
QtObject {
    // Durations (ms)
    readonly property int instant: 90
    readonly property int fast:    150
    readonly property int base:    220
    readonly property int slow:    340
    readonly property int xslow:   520

    // Easing curves — expressive but never bouncy enough to feel cheap.
    readonly property int standard:   Easing.OutCubic
    readonly property int emphasized: Easing.OutQuint
    readonly property int entrance:   Easing.OutBack
    readonly property int exit:       Easing.InCubic

    // Spring-ish overshoot for panels sliding in.
    readonly property real overshoot: 1.12
}
