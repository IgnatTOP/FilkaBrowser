import QtQuick
import Filka

// SectionLabel — the small uppercase caption that heads a group of settings or
// list section. Keeps the typographic rhythm identical everywhere.
Text {
    color: Theme.textSecondary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeXs
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
}
