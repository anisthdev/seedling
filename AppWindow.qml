import Quickshell
import QtQuick
import "components"
import "views"

// The app's one window. Keys go to whatever is on top: an open dialog or
// the key help, else the torrent list, with tremc's bindings.
FloatingWindow {
    id: window

    // [keys, what they do], for the key help (?)
    readonly property var bindings: [["j k  ↓ ↑", "Move"], ["Ctrl+f Ctrl+b", "Page down, up"], ["Ctrl+d Ctrl+u", "Half a page down, up"], ["gg G", "First, last torrent"], ["p", "Pause or resume"], ["P", "Pause or resume all"], ["N", "Start now, skipping the queue"], ["v y", "Verify local data"], ["r  Del", "Remove, keeping the files"], ["R  Shift+Del", "Remove and delete the files"], ["?  F1", "These keys"], ["q", "Quit"], ["Ctrl+w", "Quit now"]]

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
        return listKey(event);
    }

    // tremc's torrent list keys. Letters are matched by the text they
    // type, so p and P are told apart however Shift was held.
    function listKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        if (ctrl && event.key === Qt.Key_W) {
            Qt.quit();
            return true;
        }
        if (listKeys.handle(event))
            return true;

        const t = torrents.current;
        switch (event.key) {
        case Qt.Key_F1:
            help.open = true;
            return true;
        case Qt.Key_Delete:
            askRemove(t, shift);
            return true;
        }
        if (ctrl)
            return false;
        switch (event.text) {
        case "q":
            Qt.quit();
            return true;
        case "?":
            help.open = true;
            return true;
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
        case "r":
            askRemove(t, false);
            return true;
        case "R":
            askRemove(t, true);
            return true;
        }
        return false;
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
                visible: Transmission.reachable === true && Transmission.torrents.length > 0
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

        KeyHelp {
            id: help

            bindings: window.bindings
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
    }
}
