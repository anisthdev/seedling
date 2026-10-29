import Quickshell
import QtQuick
import "components"
import "views"

// The app's one window. Keys go to whatever is on top: an open dialog or
// the key help, else the torrent list or a torrent's details, with tremc's
// bindings.
FloatingWindow {
    id: window

    readonly property bool detailsOpen: Transmission.detailsId >= 0

    // [keys, what they do], for the key help (?)
    readonly property var torrentBindings: [["p", "Pause or resume"], ["P", "Pause or resume all"], ["N", "Start now, skipping the queue"], ["v y", "Verify local data"], ["L", "Seed ratio limit"], ["R  Shift+Del", "Remove and delete the files"]]
    readonly property var listBindings: [["j k  ↓ ↑", "Move"], ["Ctrl+f Ctrl+b", "Page down, up"], ["Ctrl+d Ctrl+u", "Half a page down, up"], ["gg G", "First, last torrent"], ["Enter l  →", "Details"], ...torrentBindings, ["r  Del", "Remove, keeping the files"], ["?  F1", "These keys"], ["q", "Quit"], ["Ctrl+w", "Quit now"]]
    readonly property var detailsBindings: [["o f", "Overview, files"], ["Tab Shift+Tab", "Next, previous tab"], ["j k  gg G", "Move, scroll"], ["h l  ← →", "Files: lower, raise priority"], ["", "Overview: previous, next tab"], ["Space", "Select file"], ["a", "Select all files or none"], ...torrentBindings, ["q  Esc  Backspace", "Back to the list"], ["?  F1", "These keys"], ["Ctrl+w", "Quit now"]]

    title: "Seedling"
    implicitWidth: 760
    implicitHeight: 640
    minimumSize: Qt.size(360, 300)
    // The window is the card: the launcher menu's panel colour. The menus
    // are 85% opaque but open over (dark) windows; this window sits over the
    // bright blurred wallpaper, which at 85% washes it out. At 97% it
    // measures the same as the control panel over a terminal. A rule in
    // ~/.config/hypr/windows.lua keeps Hyprland from dimming it further and
    // gives it the menus' 16px round corners.
    color: Qt.alpha(Theme.surface_container, 0.97)
    onClosed: Qt.quit()

    function handleKey(event) {
        if (help.open)
            return help.handleKey(event);
        if (confirm.open)
            return confirm.handleKey(event);
        if (input.open)
            return input.handleKey(event);
        if (event.key === Qt.Key_W && event.modifiers & Qt.ControlModifier) {
            Qt.quit();
            return true;
        }
        if (event.key === Qt.Key_F1 || event.text === "?") {
            help.open = true;
            return true;
        }
        if (detailsOpen)
            return details.handleKey(event) || torrentKey(event, details.torrent);
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
        case Qt.Key_Delete:
            if (!(event.modifiers & Qt.ShiftModifier)) {
                askRemove(t, false);
                return true;
            }
        }
        if (!ctrl)
            switch (event.text) {
            case "q":
                Qt.quit();
                return true;
            case "l":
                openDetails(t);
                return true;
            case "r":
                askRemove(t, false);
                return true;
            }
        return torrentKey(event, t);
    }

    // Keys acting on a torrent, the list's current one or the one whose
    // details are open
    function torrentKey(event, t) {
        if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
            askRemove(t, true);
            return true;
        }
        if (event.modifiers & Qt.ControlModifier)
            return false;
        switch (event.text) {
        case "p":
            if (t)
                Transmission.toggle(t);
            return true;
        case "P":
            Transmission.toggleAll();
            return true;
        case "N":
            if (t)
                Transmission.startNow([t.id]);
            return true;
        case "v":
        case "y":
            if (t)
                Transmission.verify([t.id]);
            return true;
        case "R":
            askRemove(t, true);
            return true;
        case "L":
            askSeedRatio(t);
            return true;
        }
        return false;
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

    // As tremc's L: a ratio stops seeding there; 0 (or tremc's -1) never
    // stops; nothing follows the daemon's own limit
    function askSeedRatio(t) {
        if (!t)
            return;
        const id = t.id;
        const fallback = Transmission.globalRatioLimit > 0 ? Format.ratio(Transmission.globalRatioLimit) : "unlimited";
        const current = t.seedRatioMode === 1 ? `${Math.round(t.seedRatioLimit * 100) / 100}` : t.seedRatioMode === 2 ? "0" : "";
        input.ask("Seed ratio limit", `“${t.name}” stops seeding once it has uploaded this many times its size. 0 seeds without a limit; leave it empty for the default (${fallback}).`, current, "Set", text => {
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
        }, limit => Transmission.setSeedRatio([id], limit));
    }

    function askRemove(t, deleteData) {
        if (!t)
            return;
        const id = t.id;
        if (deleteData)
            confirm.ask("Delete torrent and files?", `“${t.name}” will be removed and its downloaded files deleted.`, "Delete", () => Transmission.remove(id, true));
        else
            confirm.ask("Remove torrent?", `“${t.name}” will be removed from the list. Its files stay where they are.`, "Remove", () => Transmission.remove(id, false));
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => event.accepted = window.handleKey(event)

        Item {
            id: content

            // The launcher's padding
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 26
            anchors.bottomMargin: 20
            width: Math.min(880, parent.width - 40)

            TorrentList {
                id: torrents

                anchors.fill: parent
                visible: opacity > 0 && Transmission.reachable === true && Transmission.torrents.length > 0
                opacity: window.detailsOpen ? 0 : 1
                onActivated: window.openDetails(current)

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
                x: window.detailsOpen ? 0 : 32
                visible: opacity > 0 && Transmission.reachable === true
                opacity: window.detailsOpen ? 1 : 0
                onBack: window.closeDetails()

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

        InputDialog {
            id: input

            returnFocus: keys
        }

        KeyHelp {
            id: help

            bindings: window.detailsOpen ? window.detailsBindings : window.listBindings
        }

        ListKeys {
            id: listKeys

            list: torrents.view
            halfPage: Math.max(1, Math.floor(torrents.view.height / 90 / 2))
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
            if (window.detailsOpen && !Transmission.byId[Transmission.detailsId])
                window.closeDetails();
        }
    }
}
