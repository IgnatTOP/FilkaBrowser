# Filka Design System — Liquid Glass

Source of truth lives in QML singletons: `app/qml/theme/Theme.qml` (color,
shape, type, depth) and `app/qml/theme/Motion.qml` (timing, easing).

## Palette

**Neutrals:** Graphite Black `#0B0D10` · Deep Space Gray `#15181D` ·
Titanium `#2A2F37` · Frost White `#F4F7FB`.

**Accents:** Electric Blue `#2E7CF6` · Aurora Purple `#8B5CF6` · Cyan `#22D3EE`.
The three form the **aurora gradient** used for the wordmark, focus rings and
AI/VPN flair.

## Glass surfaces

Translucent fills (`glassLow/Med/High`) over an animated aurora backdrop create
depth. Each `GlassPanel` adds a top inner highlight + soft drop shadow. For MVP
we use **in-app layer blur** (portable); native backdrop acrylic is M7.

## Shape & spacing

Radii: 8 / 14 / 20 / 28 / pill. Spacing on a 4pt grid (4/8/12/16/24/32).

## Motion

Durations 90–520ms, easing OutCubic/OutQuint, frame-independent so it stays
smooth at 60/120/144/240Hz. Panels enter with a slight overshoot.

## Themes

`Theme.dark` toggles Light/Dark; all semantic tokens resolve per mode. Both
themes must keep AA text contrast over glass.
