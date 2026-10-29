import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Adding a torrent, as tremc's a (Ctrl+a for paused), in a Material 3
// dialog over a scrim: what to add (a magnet link, URL, .torrent file or
// bare hash; a link on the clipboard is filled in) and where to download
// it, with the free space there. Tab completes paths; Up/Down in the
// folder field go through `folders`. Enter in the first field goes on to
// the second, Enter there adds; Esc cancels. While open it takes every
// key: the fields get them first.
Item {
    id: root

    property bool open: false
    property bool paused: false
    // Where to offer downloading to, the daemon's own folder first
    property var folders: []
    property string problem
    // Bytes free in the folder, or -1 when not known
    property double free: -1
    property var onAdd: null
    // Focus goes back here on closing
    property Item returnFocus: null
    // The height it needs, for the menu to make room
    readonly property real wanted: open ? content.implicitHeight + 48 + 48 : 0

    // `added` gets the link and the folder
    function ask(paused, added) {
        root.paused = paused;
        onAdd = added;
        problem = "";
        free = -1;
        link.text = "~/Downloads/";
        folder.text = link.shorten(folders[0] ?? "");
        folder.choice = 0;
        open = true;
        link.takeFocus(false);
        clipboard.running = true;
    }

    function close() {
        open = false;
        onAdd = null;
        returnFocus?.forceActiveFocus();
    }

    // A bare info hash becomes a magnet link; paths are the daemon's to read
    function submit() {
        let what = link.text.trim();
        if (/^[0-9a-f]{40}$/i.test(what))
            what = `magnet:?xt=urn:btih:${what}`;
        else if (!/^(magnet:|https?:\/\/)/i.test(what))
            what = link.expand(what);
        if (what === "" || what.endsWith("/")) {
            problem = "Give a magnet link, a URL or a .torrent file";
            link.takeFocus(false);
            return;
        }
        if (folder.expanded === "") {
            problem = "Give a folder to download to";
            folder.takeFocus(false);
            return;
        }
        const action = onAdd;
        const dir = folder.expanded;
        close();
        action?.(what, dir);
    }

    // Keys the fields left alone: swallowed while open
    function handleKey(event) {
        return true;
    }

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    // A link already copied is likely what's to be added; read with
    // wl-paste, as the movie search does (Qt can't read the clipboard
    // before it has focus)
    Process {
        id: clipboard

        command: ["wl-paste", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: {
                const copied = text.trim();
                if (root.open && /^(magnet:\?|https?:\/\/\S+\.torrent\b|[0-9a-f]{40}$)/i.test(copied)) {
                    link.text = copied;
                    link.takeFocus(true);
                }
            }
        }
    }

    // The free space where it'd go, a moment after the folder settles
    Timer {
        id: freeTimer

        interval: 300
        onTriggered: {
            const dir = folder.expanded;
            Transmission.freeSpace(dir, bytes => {
                if (folder.expanded === dir)
                    root.free = bytes;
            });
        }
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        height: content.implicitHeight + 48
        radius: 28
        // Opaque, as ConfirmDialog
        color: Qt.alpha(Theme.surface_container_high, 1)
        opacity: scrim.opacity
        scale: 0.94 + 0.06 * scrim.opacity

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content

            x: 24
            y: 24
            width: parent.width - 48
            spacing: 12

            Label {
                anchors.verticalCenter: undefined
                bottomPadding: 4
                text: root.paused ? "Add torrent, paused" : "Add torrent"
                color: Theme.on_surface
                font.pixelSize: 24
                font.weight: Font.Normal
                roundness: Theme.titleRoundness
            }

            Label {
                anchors.verticalCenter: undefined
                text: "Magnet link, URL, .torrent file or hash"
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            PathField {
                id: link

                completion: "files"
                fileFilter: /\.torrent$/i
                onTextChanged: root.problem = ""
                onSubmitted: folder.takeFocus(false)
                onCancelled: root.close()
            }

            Label {
                anchors.verticalCenter: undefined
                topPadding: 4
                text: "Download to"
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            PathField {
                id: folder

                completion: "dirs"
                choices: root.folders
                onTextChanged: {
                    root.problem = "";
                    root.free = -1;
                    freeTimer.restart();
                }
                onSubmitted: root.submit()
                onCancelled: root.close()
            }

            Label {
                anchors.verticalCenter: undefined
                visible: root.free >= 0 || root.problem !== ""
                width: parent.width
                leftPadding: 4
                text: root.problem || `${Format.size(root.free)} free`
                color: root.problem ? Theme.error : Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                TextButton {
                    text: "Cancel  Esc"
                    onClicked: root.close()
                }

                TextButton {
                    text: "Add  ↵"
                    onClicked: root.submit()
                }
            }
        }
    }
}
