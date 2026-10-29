import QtQuick
import ".."

// A list to pick one entry from, in a dialog over a scrim, as tremc's
// menus (sort order, filter): j/k and the rest move, Enter or l picks, an
// entry's own letter picks it at once, q, h or Esc cancel (unless an entry
// claims the letter). Laid out as the launcher's grouped list, with the
// current choice checked. While open it takes every key.
//
// entries: [{ id, label, key, checked }]
Item {
    id: root

    property bool open: false
    property string title
    property var entries: []
    property var onPick: null
    // The height it needs, for the menu to make room
    readonly property real wanted: open ? card.implicitHeight + 48 : 0

    function ask(title, entries, picked) {
        root.title = title;
        root.entries = entries;
        onPick = picked;
        const checked = entries.findIndex(e => e.checked);
        list.currentIndex = Math.max(0, checked);
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        open = true;
    }

    function close() {
        open = false;
        onPick = null;
    }

    function pick(index) {
        const entry = entries[index];
        if (!entry)
            return;
        const action = onPick;
        close();
        action?.(entry);
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const byKey = ctrl || event.text === "" ? -1 : entries.findIndex(e => e.key === event.text);
        if (byKey >= 0)
            pick(byKey);
        else if (listKeys.handle(event))
            return true;
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || (!ctrl && event.text === "l"))
            pick(list.currentIndex);
        else if (event.key === Qt.Key_Escape || (!ctrl && (event.text === "q" || event.text === "h")))
            close();
        return true;
    }

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    ListKeys {
        id: listKeys

        list: list
        halfPage: 4
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
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 360)
        // From the whole list, not the clamped one: the menu makes room
        // for this
        implicitHeight: 24 + heading.implicitHeight + content.spacing + list.implicitHeight + 24
        height: Math.min(parent.height - 48, implicitHeight)
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
            spacing: 16

            Label {
                id: heading

                anchors.verticalCenter: undefined
                text: root.title
                color: Theme.on_surface
                font.pixelSize: 24
                font.weight: Font.Normal
                roundness: Theme.titleRoundness
            }

            ListView {
                id: list

                readonly property real rowHeight: 44

                width: parent.width
                implicitHeight: count * rowHeight + Math.max(0, count - 1) * spacing
                height: Math.min(implicitHeight, card.height - 48 - heading.implicitHeight - content.spacing)
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                model: root.entries

                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 220
                highlightMoveVelocity: -1
                highlight: Rectangle {
                    radius: Theme.radius
                    color: Theme.secondary_container
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property color textColor: current ? Theme.on_secondary_container : Theme.on_surface

                    width: list.width
                    height: list.rowHeight

                    // Its background, under the sliding fill (see TorrentList)
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
                        color: Qt.alpha(Theme.surface_container_highest, 1)
                        opacity: row.current ? Math.min(1, Math.abs((list.highlightItem?.y ?? row.y) - row.y) / row.height) : 1
                    }

                    Icon {
                        id: check

                        x: 14
                        visible: row.modelData.checked ?? false
                        name: "check"
                        size: 18
                        color: row.current ? Theme.on_secondary_container : Theme.primary
                    }

                    Label {
                        x: 42
                        text: row.modelData.label
                        color: row.textColor
                    }

                    // Its letter, as the launcher's keycaps
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (row.modelData.key ?? "") !== ""
                        width: Math.max(26, cap.implicitWidth + 14)
                        height: 26
                        radius: 6
                        color: row.current ? Qt.alpha(Theme.on_secondary_container, 0.12) : Qt.alpha(Theme.surface_container_highest, 1)

                        Label {
                            id: cap

                            anchors.centerIn: parent
                            text: row.modelData.key ?? ""
                            color: row.current ? Theme.on_secondary_container : Theme.on_surface_variant
                            font.family: Theme.monoFamily
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(row.index)
                        // As the launcher: the pick follows the pointer
                        onContainsMouseChanged: if (containsMouse)
                            list.currentIndex = row.index
                    }
                }
            }
        }
    }
}
