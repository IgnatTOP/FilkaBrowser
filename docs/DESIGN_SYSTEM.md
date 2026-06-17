# Filka Design System — Desktop Browser Chrome

Source of truth lives in QML singletons: `app/qml/theme/Theme.qml` (color,
shape, type, depth) and `app/qml/theme/Motion.qml` (timing, easing).

## Palette

Filka now uses restrained graphite/light browser surfaces instead of a heavy
decorative glass theme. The goal is daily-use clarity: calm chrome, readable
panels, compact controls and one clear accent color.

**Neutrals:** Obsidian `#0D1016`, Plum Gray `#171B22`, Titanium `#2A3039`,
Frost White `#F7F8FA`.

**Accent:** Coral `#FF6A4D` by default, user-selectable in settings. Accent is
reserved for focus, selected state, primary actions and security/status cues.

## Surfaces

Use semantic tokens (`chrome`, `sidebar`, `surface`, `surfaceAlt`, `card`,
`hoverFill`, `activeFill`, `outline`) instead of raw colors. Translucent glass
tokens still exist for legacy components, but new UI should prefer opaque
surfaces unless translucency improves hierarchy.

## Shape & spacing

Radii: 8 / 10 / 14 / 18 / pill. Spacing stays on a 4pt grid
(4/8/12/16/24/32/40). Browser chrome should remain dense and scannable.

## Motion

Durations are 90–340ms for normal UI. `Motion.reducedMotion` must gate
decorative movement. Prefer opacity/transform animation; avoid relayout-heavy
width/height animation except for small chrome controls.

## Themes

`Theme.dark` toggles Light/Dark; all semantic tokens resolve per mode. Both
themes must keep AA text contrast and visible focus rings.
