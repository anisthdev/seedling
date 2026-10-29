import QtQuick
import ".."
import "../components"

// One torrent in the list, as a row of the launcher's grouped list: its
// name, progress, what it's doing, then its swarm and ratio on the right,
// and pause or resume. While torrents are selected, each row shows a check
// box. The list draws its background and the sliding fill of the current
// row; there are no focus rings.
Item {
    id: row

    // The torrent's id, from the list's ScriptModel
    required property var modelData
    required property int index
    readonly property var torrent: Transmission.byId[modelData] ?? null
    property bool current: false
    property bool selecting: false
    property bool selected: false
    readonly property alias hovered: mouse.containsMouse

    signal clicked
    // Double-clicked: open its details
    signal activated
    // Its check box was clicked
    signal toggled

    readonly property string kind: torrent ? Format.kind(torrent) : "download"
    readonly property color textColor: current ? Theme.on_secondary_container : Theme.on_surface
    readonly property color detailColor: current ? Theme.on_secondary_container : Theme.on_surface_variant

    width: ListView.view?.width ?? 0
    height: info.implicitHeight + 28

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
        onDoubleClicked: row.activated()
    }

    // Check box, while selecting
    Item {
        id: check

        x: 14
        width: row.selecting ? 24 : 0
        height: parent.height
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedDecel
            }
        }

        Icon {
            name: row.selected ? "check_box" : "check_box_outline_blank"
            size: 20
            color: row.selected ? (row.current ? Theme.on_secondary_container : Theme.primary) : row.detailColor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }

    Column {
        id: info

        // The launcher's text inset, or room for the check box
        x: row.selecting ? check.x + check.width + 10 : 18
        y: 14
        width: parent.width - x - 16 - button.width
        spacing: 4

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: row.torrent?.name ?? ""
            color: row.textColor
            font.pixelSize: 14
            elide: Text.ElideMiddle
        }

        LinearProgress {
            width: parent.width
            thickness: 4
            progress: row.torrent ? Format.progress(row.torrent) : 0
            color: Format.barColor(row.kind)
            trackColor: Format.trackColor(row.kind)
        }

        Item {
            width: parent.width
            height: detail.implicitHeight

            Label {
                id: detail

                anchors.left: parent.left
                anchors.right: swarm.left
                anchors.rightMargin: 12
                text: row.torrent ? Format.statusText(row.torrent) : ""
                color: row.torrent && Format.hasError(row.torrent) ? Theme.error : row.detailColor
                font.pixelSize: 12
                font.weight: Font.Normal
                elide: Text.ElideRight
            }

            Row {
                id: swarm

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                SwarmCount {
                    icon: "arrow_upward"
                    count: row.torrent ? Format.seeders(row.torrent) : -1
                    color: row.detailColor
                }

                SwarmCount {
                    icon: "arrow_downward"
                    count: row.torrent ? Format.leechers(row.torrent) : -1
                    color: row.detailColor
                }

                Label {
                    text: row.torrent ? Format.ratioText(row.torrent) : ""
                    color: row.detailColor
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    font.features: {
                        "tnum": 1
                    }
                }
            }
        }
    }

    // Pause or resume
    IconButton {
        id: button

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 40
        implicitHeight: 40
        icon: row.torrent?.status === Format.stopped ? "media_play_arrow" : "media_pause"
        iconSize: 18
        color: row.detailColor
        onClicked: if (row.torrent)
            Transmission.toggle([row.torrent])
    }

    component SwarmCount: Row {
        property string icon
        property int count: -1
        property color color

        // Hidden until a tracker has reported the swarm
        visible: count >= 0
        spacing: 2

        Icon {
            name: parent.icon
            size: 12
            color: parent.color
        }

        Label {
            text: parent.count
            color: parent.color
            font.pixelSize: 12
            font.weight: Font.Normal
            font.features: {
                "tnum": 1
            }
        }
    }
}
