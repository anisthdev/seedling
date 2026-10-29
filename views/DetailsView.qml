import QtQuick
import ".."
import "../components"

// One torrent: its name as the title with a way back, tabs as chips (like
// the Reel menu's libraries, with their keys), what it's doing, then the
// tab's page. Keys come from the window through handleKey.
Item {
    id: root

    // [key, label] of each tab, in Tab order
    readonly property var tabs: [["o", "Overview"], ["f", "Files"]]
    property int tab: 0
    // The list's copy while the details load, then the full one
    readonly property var torrent: Transmission.details?.id === Transmission.detailsId ? Transmission.details : Transmission.byId[Transmission.detailsId] ?? null
    readonly property string kind: torrent ? Format.kind(torrent) : "download"

    signal back

    // A fresh start for another torrent
    function reset() {
        tab = 0;
        files.reset();
        overview.reset();
    }

    function switchTo(index) {
        tab = (index + tabs.length) % tabs.length;
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        // Esc drops a selection of files before it leaves
        if (tab === 1 && event.key === Qt.Key_Escape && files.selectedCount > 0)
            return files.handleKey(event);
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Backspace:
            root.back();
            return true;
        case Qt.Key_Tab:
            switchTo(tab + 1);
            return true;
        case Qt.Key_Backtab:
            switchTo(tab - 1);
            return true;
        }
        if (!ctrl) {
            if (event.text === "q") {
                root.back();
                return true;
            }
            const index = tabs.findIndex(t => t[0] === event.text);
            if (index >= 0) {
                switchTo(index);
                return true;
            }
        }
        if (tab === 1)
            return files.handleKey(event);
        // On the overview, h and l go round the tabs, as in tremc
        if (!ctrl && (event.text === "h" || event.key === Qt.Key_Left)) {
            switchTo(tab - 1);
            return true;
        }
        if (!ctrl && (event.text === "l" || event.key === Qt.Key_Right)) {
            switchTo(tab + 1);
            return true;
        }
        return overview.handleKey(event);
    }

    // The launcher's title, with its back arrow
    Row {
        id: title

        width: parent.width
        height: 34
        spacing: 4

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron"
            iconSize: 22
            color: Theme.primary
            onClicked: root.back()
        }

        Label {
            width: parent.width - 36
            height: 34
            verticalAlignment: Text.AlignVCenter
            text: root.torrent?.name ?? ""
            color: Theme.primary
            font.pixelSize: 26
            font.weight: Theme.titleWeight
            roundness: Theme.titleRoundness
            elide: Text.ElideRight
        }
    }

    // The tabs, as the Reel menu's chips
    Row {
        id: chips

        anchors.top: title.bottom
        anchors.topMargin: 14
        spacing: 8

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: chip

                required property var modelData
                required property int index
                readonly property bool on: index === root.tab

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
                        text: chip.modelData[1]
                        color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                        font.pixelSize: 15
                    }

                    Label {
                        text: chip.modelData[0]
                        color: chip.on ? Theme.on_secondary_container : Theme.outline
                        opacity: 0.7
                        font.family: Theme.monoFamily
                        font.pixelSize: 13
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(chip.index)
                }
            }
        }
    }

    // What it's doing, as its row in the list says it
    Column {
        id: status

        anchors.top: chips.bottom
        anchors.topMargin: 14
        x: 2
        width: parent.width - 4
        spacing: 4

        LinearProgress {
            width: parent.width
            thickness: 4
            progress: root.torrent ? Format.progress(root.torrent) : 0
            color: Format.barColor(root.kind)
            trackColor: Format.trackColor(root.kind)
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.torrent ? Format.statusText(root.torrent) : ""
            color: root.torrent && Format.hasError(root.torrent) ? Theme.error : Theme.on_surface_variant
            font.pixelSize: 12
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    Item {
        anchors.top: status.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        width: parent.width

        Overview {
            id: overview

            anchors.fill: parent
            visible: root.tab === 0
            torrent: root.torrent
        }

        FileList {
            id: files

            anchors.fill: parent
            visible: root.tab === 1
            torrent: root.torrent
        }
    }
}
