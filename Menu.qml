import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "components"
import "views"

// Seedling as one of the shell's menus, like its movie search: a panel at
// the bottom centre that springs open upwards, growing to fit the list or
// the details, and folds back down. `qs -p <dir> ipc call seedling toggle`
// opens and closes it; it opens on starting. Keys go to whatever is on top:
// an open dialog or the key help, else the torrent list or a torrent's
// details, with tremc's bindings.
Scope {
    id: menu

    property bool open: false

    readonly property bool detailsOpen: Transmission.detailsId >= 0

    // [keys, what they do], for the key help (?)
    readonly property var torrentBindings: [["p", "Pause or resume"], ["P", "Pause or resume all shown"], ["N", "Start now, skipping the queue"], ["v y", "Verify local data"], ["L", "Seed ratio limit"], ["R  Shift+Del", "Remove one, deleting its files"]]
    readonly property var listBindings: [["j k  ↓ ↑", "Move"], ["Ctrl+f Ctrl+b", "Page down, up"], ["Ctrl+d Ctrl+u", "Half a page down, up"], ["gg G", "First, last torrent"], ["Enter l  →", "Details"], ["/", "Find by name"], ["f", "Filter"], ["s", "Sort"], ["Space", "Select, and move down"], ["A", "Select all or none"], ["i", "Invert the selection"], ["", "The rest act on the selection, else the current one:"], ...torrentBindings, ["r  Del", "Remove, keeping the files"], ["?  F1", "These keys"], ["Esc", "Drop the selection, the search, then close"], ["q  Ctrl+w", "Close"]]
    readonly property var detailsBindings: [["o f", "Overview, files"], ["Tab Shift+Tab", "Next, previous tab"], ["j k  gg G", "Move, scroll"], ["h l  ← →", "Files: lower, raise priority"], ["", "Overview: previous, next tab"], ["Space", "Files: select; overview: more details"], ["a", "Select all files or none"], ...torrentBindings, ["q  Esc  Backspace", "Back to the list"], ["?  F1", "These keys"], ["Ctrl+w", "Close"]]

    function show() {
        open = true;
        keys.forceActiveFocus();
    }

    function hide() {
        open = false;
        torrents.stopSearch();
    }

    // Polls the daemon only while open
    onOpenChanged: Transmission.active = open
    Component.onCompleted: show()

    function handleKey(event) {
        if (help.open)
            return help.handleKey(event);
        if (confirm.open)
            return confirm.handleKey(event);
        if (input.open)
            return input.handleKey(event);
        if (picker.open)
            return picker.handleKey(event);
        if (event.key === Qt.Key_W && event.modifiers & Qt.ControlModifier) {
            hide();
            return true;
        }
        if (event.key === Qt.Key_F1 || event.text === "?") {
            help.open = true;
            return true;
        }
        if (detailsOpen)
            return details.handleKey(event) || torrentKey(event, details.torrent ? [details.torrent] : [], details.torrent);
        return listKey(event);
    }

    // tremc's torrent list keys. Letters are matched by the text they
    // type, so p and P are told apart however Shift was held.
    function listKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (listKeys.handle(event))
            return true;

        const t = torrents.current;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Right:
            openDetails(t);
            return true;
        // Lets go of one thing at a time: the selection, the search, then
        // the menu
        case Qt.Key_Escape:
            if (torrents.selectedIds.length > 0)
                torrents.clearSelection();
            else if (torrents.query !== "")
                torrents.clearSearch();
            else
                hide();
            return true;
        case Qt.Key_Space:
            torrents.toggleCurrent();
            return true;
        case Qt.Key_Delete:
            if (!(event.modifiers & Qt.ShiftModifier)) {
                askRemove(torrents.targets(), false);
                return true;
            }
        }
        if (!ctrl)
            switch (event.text) {
            case "q":
                hide();
                return true;
            case "l":
                openDetails(t);
                return true;
            case "r":
                askRemove(torrents.targets(), false);
                return true;
            case "/":
                torrents.startSearch();
                return true;
            case "f":
                askFilter();
                return true;
            case "s":
                picker.ask("Sort by", torrents.sortEntries(), e => torrents.setSort(e.id));
                return true;
            case "A":
                torrents.selectAll();
                return true;
            case "i":
                torrents.invertSelection();
                return true;
            }
        return torrentKey(event, torrents.targets(), t);
    }

    // Keys acting on torrents: `list` is what most act on (the list's
    // selection, else its current torrent; or the one whose details are
    // open), `t` the current one alone, for R as in tremc
    function torrentKey(event, list, t) {
        if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
            askRemove(t ? [t] : [], true);
            return true;
        }
        if (event.modifiers & Qt.ControlModifier)
            return false;
        const ids = list.map(t => t.id);
        switch (event.text) {
        case "p":
            Transmission.toggle(list);
            return true;
        case "P":
            Transmission.toggleAll(torrents.shown);
            return true;
        case "N":
            Transmission.startNow(ids);
            return true;
        case "v":
        case "y":
            Transmission.verify(ids);
            return true;
        case "R":
            askRemove(t ? [t] : [], true);
            return true;
        case "L":
            askSeedRatio(list);
            return true;
        }
        return false;
    }

    // As tremc's f: what to show, a location from a second list
    function askFilter() {
        picker.ask("Show only", torrents.filterEntries(), e => {
            if (e.id === "location")
                Qt.callLater(() => picker.ask("Location", torrents.locationEntries(), d => torrents.setFilter("location", d.id)));
            else
                torrents.setFilter(e.id);
        });
    }

    function openDetails(t) {
        if (!t)
            return;
        details.reset();
        Transmission.detailsId = t.id;
    }

    function closeDetails() {
        Transmission.detailsId = -1;
    }

    // How a dialog names the torrents it's about
    function describe(list) {
        return list.length === 1 ? `“${list[0].name}”` : `These ${list.length} torrents`;
    }

    // As tremc's L: a ratio stops seeding there; 0 (or tremc's -1) never
    // stops; nothing follows the daemon's own limit. Starts from the first
    // one's limit.
    function askSeedRatio(list) {
        if (list.length === 0)
            return;
        const ids = list.map(t => t.id);
        const t = list[0];
        const fallback = Transmission.globalRatioLimit > 0 ? Format.ratio(Transmission.globalRatioLimit) : "unlimited";
        const current = t.seedRatioMode === 1 ? `${Math.round(t.seedRatioLimit * 100) / 100}` : t.seedRatioMode === 2 ? "0" : "";
        input.ask("Seed ratio limit", `${describe(list)} ${list.length === 1 ? "stops" : "stop"} seeding once uploaded this many times ${list.length === 1 ? "its" : "their"} size. 0 seeds without a limit; leave it empty for the default (${fallback}).`, current, "Set", text => {
            const trimmed = text.trim();
            if (trimmed === "")
                return {
                    value: "default"
                };
            const ratio = Number(trimmed);
            if (isNaN(ratio) || (ratio < 0 && ratio !== -1))
                return "Enter a ratio, like 2 or 1.5";
            return {
                value: ratio <= 0 ? "unlimited" : ratio
            };
        }, limit => Transmission.setSeedRatio(ids, limit));
    }

    function askRemove(list, deleteData) {
        if (list.length === 0)
            return;
        const ids = list.map(t => t.id);
        const what = describe(list);
        const many = list.length > 1;
        if (deleteData)
            confirm.ask(many ? `Delete ${list.length} torrents and files?` : "Delete torrent and files?", `${what} will be removed and ${many ? "their" : "its"} downloaded files deleted.`, "Delete", () => Transmission.remove(ids, true));
        else
            confirm.ask(many ? `Remove ${list.length} torrents?` : "Remove torrent?", `${what} will be removed from the list. ${many ? "Their" : "Its"} files stay where they are.`, "Remove", () => Transmission.remove(ids, false));
    }


    PanelWindow {
        id: surface

        // Spring open upwards, fold back quicker, as the shell's menus
        property real reveal: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Mapped from opening until the fold-away has finished
        visible: false
        // The shell's menus' name, so Hyprland blurs it as it blurs them and
        // leaves out its layer slide (the surface covers the screen)
        WlrLayershell.namespace: "quickbar-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: menu
            function onOpenChanged() {
                if (menu.open) {
                    closeAnim.stop();
                    surface.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    closeAnim.restart();
                }
            }
        }

        NumberAnimation {
            id: openAnim

            target: surface
            property: "reveal"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            id: closeAnim

            target: surface
            property: "reveal"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
            onFinished: surface.visible = false
        }

        // A click anywhere else closes it
        MouseArea {
            anchors.fill: parent
            onClicked: menu.hide()
        }

        Rectangle {
            id: panel

            // Room for the page, or for an open dialog, up to most of the
            // screen
            property real fullHeight: Math.min(surface.height - 32 - 60, Math.max(26 + content.wanted + 20, confirm.wanted, input.wanted, picker.wanted, help.wanted))

            // Bottom centre, where the shell's menus open, growing upwards
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: Math.min(820, surface.width - 32)
            height: Math.max(0, fullHeight * surface.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            // The same pace as the search field's (TorrentList), which
            // grows alongside it
            Behavior on fullHeight {
                enabled: menu.open && !openAnim.running
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }

            // Swallow clicks on the panel itself
            MouseArea {
                anchors.fill: parent
            }

            // Laid out at full height, so folding only uncovers it
            Item {
                width: parent.width
                height: panel.fullHeight

                Item {
                    id: keys

                    anchors.fill: parent
                    Keys.onPressed: event => event.accepted = menu.handleKey(event)

                    Item {
                        id: content

                        // What the current page would like, before the panel's limit
                        readonly property real wanted: {
                            if (Transmission.reachable === false || Transmission.torrents.length === 0)
                                return 260;
                            return menu.detailsOpen ? details.implicitHeight : torrents.implicitHeight;
                        }

                        // The launcher's padding
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.topMargin: 26
                        anchors.bottomMargin: 20

                        TorrentList {
                            id: torrents

                            anchors.fill: parent
                            visible: opacity > 0 && Transmission.reachable === true && Transmission.torrents.length > 0
                            opacity: menu.detailsOpen ? 0 : 1
                            returnFocus: keys
                            onActivated: menu.openDetails(current)
                            onSortClicked: picker.ask("Sort by", sortEntries(), e => setSort(e.id))
                            onFilterClicked: menu.askFilter()

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                        }

                        // Comes in from the right over the list, and goes back there
                        DetailsView {
                            id: details

                            width: parent.width
                            height: parent.height
                            x: menu.detailsOpen ? 0 : 32
                            visible: opacity > 0 && Transmission.reachable === true
                            opacity: menu.detailsOpen ? 1 : 0
                            onBack: menu.closeDetails()

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.animNormal
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.emphasizedDecel
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                        }

                        StatusPage {
                            visible: Transmission.reachable === false
                            title: "Can’t reach transmission-daemon"
                            description: `${Transmission.problem}. Make sure it is running and listening on localhost:9091; trying again every 2 seconds.`
                        }

                        StatusPage {
                            visible: Transmission.reachable === true && Transmission.torrents.length === 0
                            title: "No torrents"
                            description: "Torrents added to transmission-daemon show up here."
                        }
                    }

                    Snackbar {
                        id: snackbar
                    }

                    ConfirmDialog {
                        id: confirm
                    }

                    PickerDialog {
                        id: picker
                    }

                    InputDialog {
                        id: input

                        returnFocus: keys
                    }

                    KeyHelp {
                        id: help

                        bindings: menu.detailsOpen ? menu.detailsBindings : menu.listBindings
                    }

                    ListKeys {
                        id: listKeys

                        list: torrents.view
                        halfPage: Math.max(1, Math.floor(torrents.view.height / 90 / 2))
                    }
                }

            }
        }
    }

    IpcHandler {
        target: "seedling"

        function toggle(): void {
            menu.open ? menu.hide() : menu.show();
        }

        function open(): void {
            menu.show();
        }

        function close(): void {
            menu.hide();
        }
    }

    Connections {
        target: Transmission

        function onFailed(message) {
            snackbar.show(message);
        }

        function onRemoved(message) {
            snackbar.show(message);
        }

        // The open torrent was removed, here or elsewhere
        function onTorrentsChanged() {
            if (menu.detailsOpen && !Transmission.byId[Transmission.detailsId])
                menu.closeDetails();
        }
    }
}
