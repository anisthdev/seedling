import Quickshell
import QtQuick
import ".."
import "../components"

// A torrent's files by path, as the torrent list: a grouped list with the
// sliding fill on the current file. tremc's keys: j/k and the rest move,
// h/l lower and raise the priority (skip < low < normal < high) of the
// selected files or else the current one, Space selects, a selects all or
// none, Esc drops the selection.
Item {
    id: root

    property var torrent: null
    // index into the torrent's files → true
    property var selected: ({})
    readonly property int selectedCount: Object.keys(selected).length
    // File indexes, by path
    readonly property var order: {
        const files = torrent?.files ?? [];
        return files.map((f, i) => i).sort((a, b) => files[a].name.localeCompare(files[b].name, undefined, {
                numeric: true
            }));
    }
    readonly property int currentFile: order[list.currentIndex] ?? -1

    function reset() {
        selected = {};
        list.currentIndex = 0;
        list.positionViewAtBeginning();
    }

    // What h and l act on
    function targets() {
        if (selectedCount > 0)
            return Object.keys(selected).map(Number);
        return currentFile >= 0 ? [currentFile] : [];
    }

    function toggle(index) {
        const next = Object.assign({}, selected);
        if (next[index])
            delete next[index];
        else
            next[index] = true;
        selected = next;
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (listKeys.handle(event))
            return true;
        if (event.key === Qt.Key_Escape && selectedCount > 0) {
            selected = {};
            return true;
        }
        if (event.key === Qt.Key_Left || (!ctrl && event.text === "h")) {
            Transmission.stepFiles(targets(), -1);
            return true;
        }
        if (event.key === Qt.Key_Right || (!ctrl && event.text === "l")) {
            Transmission.stepFiles(targets(), 1);
            return true;
        }
        if (ctrl)
            return false;
        if (event.key === Qt.Key_Space) {
            if (currentFile >= 0)
                toggle(currentFile);
            return true;
        }
        if (event.text === "a") {
            const all = {};
            if (selectedCount < order.length)
                for (const i of order)
                    all[i] = true;
            selected = all;
            return true;
        }
        return false;
    }

    ListKeys {
        id: listKeys

        list: list
        halfPage: Math.max(1, Math.floor(list.height / 80 / 2))
    }

    ListView {
        id: list

        anchors.fill: parent
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false

        model: ScriptModel {
            values: root.order
        }

        // As the torrent list: keep the pick in view, and bring jumps into
        // view at once
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        property int lastIndex: 0
        onCurrentIndexChanged: {
            if (Math.abs(currentIndex - lastIndex) > 1) {
                const index = currentIndex;
                Qt.callLater(() => list.positionViewAtIndex(index, ListView.Contain));
            }
            lastIndex = currentIndex;
        }

        highlightFollowsCurrentItem: true
        highlightMoveDuration: 220
        highlightMoveVelocity: -1
        highlightResizeDuration: Theme.animNormal
        highlightResizeVelocity: -1
        highlight: Rectangle {
            radius: Theme.radius
            color: Theme.secondary_container
        }

        delegate: FileRow {
            id: row

            torrent: root.torrent
            current: ListView.isCurrentItem
            selecting: root.selectedCount > 0
            selected: root.selected[modelData] === true
            onClicked: list.currentIndex = index
            onToggled: root.toggle(modelData)

            // The row's background, under the sliding fill (see TorrentList)
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
    }
}
