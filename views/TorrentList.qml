import Quickshell
import QtQuick
import ".."
import "../components"

// The title and every torrent, laid out like quickbar's launcher menu: a
// grouped list whose pick is a fill sliding from row to row. Keys are
// handled by the window, which moves `view.currentIndex`.
Item {
    id: root

    property alias view: list
    readonly property var current: Transmission.byId[Transmission.ids[list.currentIndex]] ?? null

    // The launcher's title
    Label {
        id: title

        anchors.verticalCenter: undefined
        height: 34
        leftPadding: 2
        verticalAlignment: Text.AlignVCenter
        text: "Torrents"
        color: Theme.primary
        font.pixelSize: 26
        font.weight: Theme.titleWeight
        roundness: Theme.titleRoundness
    }

    ListView {
        id: list

        anchors.top: title.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // The window's keys move the pick, tremc style
        keyNavigationEnabled: false

        model: ScriptModel {
            values: Transmission.ids
        }

        // Keep the pick in view as the keys move it
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        // Jumps (gg, G, Ctrl+f) bring their row into view at once: the
        // range alone lags a move behind across rows not built yet
        property int lastIndex: 0
        onCurrentIndexChanged: {
            if (Math.abs(currentIndex - lastIndex) > 1) {
                const index = currentIndex;
                Qt.callLater(() => list.positionViewAtIndex(index, ListView.Contain));
            }
            lastIndex = currentIndex;
        }

        // The pick's fill slides from row to row, as in the launcher: above
        // the rows' backgrounds (on a layer of their own, below) and under
        // their text
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 220
        highlightMoveVelocity: -1
        highlightResizeDuration: Theme.animNormal
        highlightResizeVelocity: -1
        highlight: Rectangle {
            radius: Theme.radius
            color: Theme.secondary_container
        }

        delegate: TorrentRow {
            id: row

            current: ListView.isCurrentItem
            onClicked: list.currentIndex = index

            // The row's background, moved under the sliding fill. The
            // current row's is hidden, so the fill's round corners show.
            Rectangle {
                readonly property real topCorners: row.index === 0 ? Theme.radius : 3
                readonly property real bottomCorners: row.index === list.count - 1 ? Theme.radius : 3

                parent: list.contentItem
                z: -1
                x: row.x
                y: row.y
                width: row.width
                height: row.height
                topLeftRadius: topCorners
                topRightRadius: topCorners
                bottomLeftRadius: bottomCorners
                bottomRightRadius: bottomCorners
                color: row.hovered ? Theme.surface_container_highest : Theme.surface_container_high
                visible: !row.current
            }
        }

        // Always a pick once there are torrents, as in tremc
        onCountChanged: if (currentIndex < 0 && count > 0)
            currentIndex = 0
    }
}
