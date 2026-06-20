import QtQuick
import Filka

IconButton {
    id: root

    property string idleAccessibleName: qsTr("Выполнить действие")
    property string confirmAccessibleName: qsTr("Подтвердить действие")
    property string idleTooltip: idleAccessibleName
    property string confirmTooltip: confirmAccessibleName
    property bool destructive: true

    signal confirmed()

    iconColor: destructive ? Theme.danger : Theme.iconMuted
    active: confirmTimer.running
    tooltip: confirmTimer.running ? confirmTooltip : idleTooltip
    Accessible.name: confirmTimer.running ? confirmAccessibleName : idleAccessibleName

    onClicked: {
        if (!confirmTimer.running) {
            confirmTimer.restart()
            return
        }
        confirmTimer.stop()
        root.confirmed()
    }

    Timer {
        id: confirmTimer
        interval: Motion.actionFeedbackTimeout
    }
}
