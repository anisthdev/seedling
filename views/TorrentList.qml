import Quickshell
import QtQuick
import ".."
import "../components"

// The title and the torrents, laid out like quickbar's launcher menu: a
// grouped list whose pick is a fill sliding from row to row. Beside the
// title, chips show the sort order, the filter and the selection, as the
// Reel menu's chips, with their keys. `/` opens a field under the title
// that narrows the list by name as it's typed, as the launcher's filter.
// Keys are handled by the menu, which moves `view.currentIndex` and calls
// the functions here.
Item {
    id: root

    property alias view: list
    // Gets the keys back when the search field lets them go
    property Item returnFocus: null

    // The list's state, as tremc's: what's searched, the filter (`f`), the
    // sort order (`s`), the selection (Space, A, i)
    property string query: field.text
    readonly property bool searching: field.activeFocus
    property var filter: ({
            id: "all",
            inverse: false
        })
    property var sort: ({
            id: "addedDate",
            reverse: false
        })
    // id → true
    property var selected: ({})

    // [id, label, key, test]: tremc's filters, with its letters
    readonly property var filters: [["all", "All", "a", t => true], ["uploading", "Uploading", "u", t => t.rateUpload > 0], ["downloading", "Downloading", "d", t => t.rateDownload > 0], ["active", "Active", "t", t => t.peersGettingFromUs > 0 || t.peersSendingToUs > 0 || t.status === Format.verifying], ["paused", "Paused", "p", t => t.status === Format.stopped], ["seeding", "Seeding", "s", t => t.status === Format.seeding || t.status === Format.queuedToSeed], ["incomplete", "Incomplete", "c", t => t.percentDone < 1], ["verifying", "Verifying", "y", t => t.status === Format.verifying || t.status === Format.queuedToVerify], ["private", "Private", "r", t => t.isPrivate], ["selected", "Selected", "e", t => root.selected[t.id] === true], ["error", "Error or warning", "g", t => t.error > 0], ["location", "Location…", "o", t => root.folder(t.downloadDir) === root.filter.location]]
    // [id, label, key, value, descending]: tremc's sort orders, with its
    // letters. Each goes the way that's most useful first (biggest, most
    // recent), Reverse turns it round; ties go by name.
    readonly property var sorts: [["name", "Name", "n", t => t.name.toLowerCase(), false], ["addedDate", "Age", "a", t => t.addedDate, false], ["percentDone", "Progress", "p", t => t.percentDone, true], ["seeders", "Seeds", "s", t => Format.seeders(t), true], ["leechers", "Leeches", "c", t => Format.leechers(t), true], ["sizeWhenDone", "Size", "z", t => t.sizeWhenDone, true], ["status", "Status", "t", t => t.status, true], ["uploadedEver", "Uploaded", "l", t => t.uploadedEver, true], ["rateUpload", "Upload speed", "u", t => t.rateUpload, true], ["rateDownload", "Download speed", "d", t => t.rateDownload, true], ["uploadRatio", "Ratio", "r", t => t.uploadRatio, true], ["peersConnected", "Peers", "e", t => t.peersConnected, true], ["downloadDir", "Location", "o", t => t.downloadDir.toLowerCase(), false], ["queuePosition", "Queue position", "q", t => t.queuePosition, false], ["activityDate", "Last activity", "y", t => t.activityDate, true], ["eta", "Time left", "f", t => t.eta < 0 ? Infinity : t.eta, false], ["doneDate", "Time done", "i", t => t.doneDate, true]]

    // What the list shows, in order
    readonly property var shown: {
        const f = filters.find(f => f[0] === filter.id) ?? filters[0];
        const q = query.trim().toLowerCase();
        const s = sorts.find(s => s[0] === sort.id) ?? sorts[1];
        const way = (s[4] ? -1 : 1) * (sort.reverse ? -1 : 1);
        const list = Transmission.torrents.filter(t => (f[3](t) !== filter.inverse || filter.id === "all") && (q === "" || t.name.toLowerCase().includes(q)));
        const keyed = list.map(t => [s[3](t), t.name.toLowerCase(), t]);
        keyed.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0) * way || a[1].localeCompare(b[1]));
        return keyed.map(k => k[2]);
    }
    readonly property var shownIds: shown.map(t => t.id)
    readonly property var current: Transmission.byId[shownIds[list.currentIndex]] ?? null
    // The selection, of what's shown
    readonly property var selectedIds: shownIds.filter(id => selected[id] === true)

    // What commands act on: the selection, or the current torrent
    function targets() {
        if (selectedIds.length > 0)
            return selectedIds.map(id => Transmission.byId[id]);
        return current ? [current] : [];
    }

    readonly property string filterText: {
        if (filter.id === "all")
            return "All";
        const label = filter.id === "location" ? `In ${filter.location.split("/").pop()}` : filters.find(f => f[0] === filter.id)[1];
        return filter.inverse ? `Not ${label.toLowerCase()}` : label;
    }
    readonly property string sortText: (sorts.find(s => s[0] === sort.id) ?? sorts[1])[1] + (sort.reverse ? ", reversed" : "")

    // For the menu's pickers: [{ id, label, key, checked }]
    function filterEntries() {
        return filters.map(f => ({
                    id: f[0],
                    label: f[1],
                    key: f[2],
                    checked: f[0] === filter.id
                })).concat([
            {
                id: "invert",
                label: "Invert",
                key: "v",
                checked: filter.inverse
            }
        ]);
    }

    // A download folder, the same however the daemon wrote it ("~/Movies/"
    // and "~/Movies" are one)
    function folder(dir) {
        return dir.replace(/\/+$/, "");
    }

    function locationEntries() {
        const dirs = [...new Set(Transmission.torrents.map(t => folder(t.downloadDir)))].sort();
        return dirs.map(d => ({
                    id: d,
                    label: d.replace(Quickshell.env("HOME"), "~"),
                    checked: filter.id === "location" && filter.location === d
                }));
    }

    function sortEntries() {
        return sorts.map(s => ({
                    id: s[0],
                    label: s[1],
                    key: s[2],
                    checked: s[0] === sort.id
                })).concat([
            {
                id: "reverse",
                label: "Reverse",
                key: "v",
                checked: sort.reverse
            }
        ]);
    }

    function setFilter(id, location) {
        if (id === "invert")
            filter = Object.assign({}, filter, {
                inverse: !filter.inverse
            });
        else
            filter = {
                id: id,
                inverse: false,
                location: location
            };
    }

    function setSort(id) {
        sort = id === "reverse" ? Object.assign({}, sort, {
            reverse: !sort.reverse
        }) : {
            id: id,
            reverse: false
        };
    }

    // As tremc's Space: select or drop the current torrent, then move on
    function toggleCurrent() {
        if (!current)
            return;
        const next = Object.assign({}, selected);
        if (next[current.id])
            delete next[current.id];
        else
            next[current.id] = true;
        selected = next;
        list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
    }

    function toggle(id) {
        const next = Object.assign({}, selected);
        if (next[id])
            delete next[id];
        else
            next[id] = true;
        selected = next;
    }

    // As tremc's A: none if any are selected, else all
    function selectAll() {
        const next = {};
        if (selectedIds.length === 0)
            for (const id of shownIds)
                next[id] = true;
        selected = next;
    }

    function invertSelection() {
        const next = {};
        for (const id of shownIds)
            if (!selected[id])
                next[id] = true;
        selected = next;
    }

    function clearSelection() {
        selected = {};
    }

    function startSearch() {
        field.forceActiveFocus();
        field.selectAll();
    }

    function stopSearch() {
        if (field.activeFocus)
            returnFocus?.forceActiveFocus();
    }

    function clearSearch() {
        field.text = "";
        stopSearch();
    }

    // Its whole height, for the menu to fit. Rows are all one height,
    // measured on a hidden one: the list's own contentHeight depends on its
    // height, which this sets.
    // The field counts at its full size from the start, so the menu grows
    // alongside it rather than chasing it.
    implicitHeight: header.height + (fieldBox.shown ? 14 + 46 : 0) + 14 + (list.count > 0 ? list.count * probe.height + (list.count - 1) * list.spacing : nothing.implicitHeight)

    TorrentRow {
        id: probe

        modelData: -1
        index: -1
        visible: false
    }

    // A row was double-clicked (it's current by then)
    signal activated
    // A chip was clicked
    signal sortClicked
    signal filterClicked

    // The launcher's title, and the chips
    Row {
        id: header

        width: parent.width
        height: 34
        spacing: 18

        Label {
            height: 34
            leftPadding: 2
            verticalAlignment: Text.AlignVCenter
            text: "Torrents"
            color: Theme.primary
            font.pixelSize: 26
            font.weight: Theme.titleWeight
            roundness: Theme.titleRoundness
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Chip {
                text: root.sortText
                key: "s"
                onClicked: root.sortClicked()
            }

            Chip {
                text: root.filterText
                key: "f"
                on: root.filter.id !== "all"
                onClicked: root.filterClicked()
            }

            Chip {
                visible: root.selectedIds.length > 0
                text: `${root.selectedIds.length} selected`
                icon: "close"
                on: true
                onClicked: root.clearSelection()
            }
        }
    }

    // The launcher's filter field, here while searching or narrowed
    Rectangle {
        id: fieldBox

        readonly property bool shown: root.searching || root.query !== ""
        // 0 to 1 as it opens: its gap and height together, at the menu
        // panel's own pace, so the panel grows by just as much at once and
        // the list below keeps its height (and its scroll) throughout
        property real reveal: shown ? 1 : 0

        anchors.top: header.bottom
        anchors.topMargin: 14 * reveal
        width: parent.width
        height: 46 * reveal
        visible: reveal > 0
        opacity: reveal
        clip: true
        radius: Theme.radius
        color: Theme.surface_container_highest
        border.width: root.searching ? 2 : 0
        border.color: Theme.primary

        Behavior on reveal {
            NumberAnimation {
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedDecel
            }
        }

        // A click focuses it, as / does
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.startSearch()
        }

        Icon {
            anchors.left: parent.left
            anchors.leftMargin: 14
            name: "search"
            size: 20
            color: Theme.on_surface_variant
        }

        TextInput {
            id: field

            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.on_surface
            selectionColor: Theme.primary
            selectedTextColor: Theme.on_primary
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.Medium
            clip: true
            onTextChanged: list.currentIndex = 0

            // Typing narrows the list; these move through it and leave, as
            // the launcher's field
            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                switch (event.key) {
                case Qt.Key_Escape:
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.stopSearch();
                    break;
                case Qt.Key_Down:
                case Qt.Key_Tab:
                    move(1);
                    break;
                case Qt.Key_Up:
                case Qt.Key_Backtab:
                    move(-1);
                    break;
                case Qt.Key_J:
                case Qt.Key_N:
                    if (!ctrl)
                        return;
                    move(1);
                    break;
                case Qt.Key_K:
                case Qt.Key_P:
                    if (!ctrl)
                        return;
                    move(-1);
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            function move(by) {
                list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + by));
            }
        }

        Label {
            anchors.left: field.left
            visible: field.text === ""
            text: "Find a torrent…"
            color: Theme.on_surface_variant
            font.pixelSize: 16
            font.weight: Font.Normal
        }
    }

    ListView {
        id: list

        anchors.top: fieldBox.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // The menu's keys move the pick, tremc style
        keyNavigationEnabled: false

        model: ScriptModel {
            values: root.shownIds
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
            currentId = root.shownIds[currentIndex] ?? -1;
        }

        // The pick stays on its torrent as the order changes, as in tremc
        property int currentId: -1
        Connections {
            target: root
            function onShownIdsChanged() {
                Qt.callLater(() => {
                    const index = root.shownIds.indexOf(list.currentId);
                    if (index >= 0)
                        list.currentIndex = index;
                    else
                        list.currentIndex = Math.min(Math.max(0, list.currentIndex), list.count - 1);
                });
            }
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
            selecting: root.selectedIds.length > 0
            selected: root.selected[modelData] === true
            onClicked: list.currentIndex = index
            onToggled: root.toggle(modelData)
            onActivated: {
                list.currentIndex = index;
                root.activated();
            }

            // The row's background, moved under the sliding fill. The
            // current row's goes once the fill is over it, so the fill's
            // round corners show.
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
                // Fades as the fill arrives: hidden at once, the darker
                // panel would show until the fill got there
                opacity: row.current ? Math.min(1, Math.abs((list.highlightItem?.y ?? row.y) - row.y) / row.height) : 1
            }
        }

        // Always a pick once there are torrents, as in tremc
        onCountChanged: if (currentIndex < 0 && count > 0)
            currentIndex = 0
    }

    // Nothing left by the search or the filter
    Label {
        id: nothing

        anchors.top: fieldBox.bottom
        anchors.topMargin: 14
        visible: list.count === 0
        leftPadding: 4
        bottomPadding: 6
        text: "No torrents match"
        color: Theme.on_surface_variant
        font.pixelSize: 14
        font.weight: Font.Normal
    }

    // A chip beside the title, as the Reel menu's: what it shows, and its
    // key or an icon
    component Chip: Rectangle {
        id: chip

        property string text
        property string key
        property string icon
        property bool on: false

        signal clicked

        width: chipRow.implicitWidth + 28
        height: 34
        radius: 17
        color: on ? Theme.secondary_container : Theme.surface_container_high

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 8

            Label {
                text: chip.text
                color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                font.pixelSize: 15
            }

            Label {
                visible: chip.key !== ""
                text: chip.key
                color: chip.on ? Theme.on_secondary_container : Theme.outline
                opacity: 0.7
                font.family: Theme.monoFamily
                font.pixelSize: 13
            }

            Icon {
                visible: chip.icon !== ""
                name: chip.icon
                size: 16
                color: Theme.on_secondary_container
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
