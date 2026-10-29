import QtQuick
import ".."
import "../components"

// One file of a torrent, as a torrent row: its name, progress, folder and
// size, and its priority on the right. While files are selected, each row
// shows a check box. Skipped files are dimmed.
Item {
    id: row

    // The file's index into the torrent's files, from the list's model
    required property var modelData
    required property int index
    property var torrent: null
    property bool current: false
    property bool selecting: false
    property bool selected: false
    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal toggled

    readonly property var file: torrent?.files?.[modelData] ?? null
    readonly property var stats: torrent?.fileStats?.[modelData] ?? null
    readonly property int level: stats ? Transmission.fileLevel(stats) : 0
    readonly property bool skipped: level === -2
    readonly property real done: file && file.length > 0 ? file.bytesCompleted / file.length : 0
    readonly property color textColor: current ? Theme.on_secondary_container : Theme.on_surface
    readonly property color detailColor: current ? Theme.on_secondary_container : Theme.on_surface_variant

    // The path without the torrent's own folder and the file's name
    readonly property string folder: {
        const parts = (file?.name ?? "").split("/");
        return parts.slice(1, -1).join("/");
    }

    width: ListView.view?.width ?? 0
    height: info.implicitHeight + 28

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
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

        x: row.selecting ? check.x + check.width + 10 : 18
        y: 14
        width: parent.width - x - 16 - priority.width - 12
        spacing: 4
        opacity: row.skipped ? 0.6 : 1

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: row.file?.name.split("/").pop() ?? ""
            color: row.textColor
            font.pixelSize: 14
            elide: Text.ElideMiddle
        }

        LinearProgress {
            width: parent.width
            thickness: 4
            progress: row.done
            color: Format.barColor(row.skipped ? "paused" : "download")
            trackColor: Format.trackColor(row.skipped ? "paused" : "download")
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: {
                if (!row.file)
                    return "";
                const size = row.done >= 1 ? Format.size(row.file.length) : `${Format.size(row.file.bytesCompleted)} of ${Format.size(row.file.length)} · ${Format.percent(row.done)}`;
                return row.folder ? `${row.folder} · ${size}` : size;
            }
            color: row.detailColor
            font.pixelSize: 12
            font.weight: Font.Normal
            elide: Text.ElideMiddle
        }
    }

    // The priority, as a chip: h and l step it
    Rectangle {
        id: priority

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 72
        height: 28
        radius: 14
        color: row.level === 1 ? Theme.primary_container : row.current ? Qt.alpha(Theme.on_secondary_container, 0.12) : Theme.surface_container_highest

        Label {
            anchors.centerIn: parent
            text: Format.priority(row.level)
            color: row.level === 1 ? Theme.on_primary_container : row.skipped ? Theme.outline : row.detailColor
            font.pixelSize: 12
        }
    }
}
