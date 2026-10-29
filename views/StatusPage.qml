import QtQuick
import ".."
import "../components"

// A message filling the window: no torrents, or no daemon.
Column {
    id: root

    property string icon: "download"
    property string title
    property string description

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 440)
    spacing: 12

    Icon {
        anchors.verticalCenter: undefined
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.icon
        size: 48
        color: Theme.on_surface_variant
    }

    Label {
        anchors.verticalCenter: undefined
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        color: Theme.on_surface
        font.pixelSize: 24
        font.weight: Font.Normal
        roundness: Theme.titleRoundness
        wrapMode: Text.WordWrap
    }

    Label {
        anchors.verticalCenter: undefined
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.description
        color: Theme.on_surface_variant
        font.weight: Font.Normal
        wrapMode: Text.WordWrap
    }
}
