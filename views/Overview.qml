import QtQuick
import ".."
import "../components"

// What a torrent is doing, in the launcher's grouped-list rows: what each
// thing is on the left, its value on the right. A short summary first;
// Space (or the row under it) shows the rest. The keys scroll it (j/k,
// gg/G, Ctrl+d/u, Ctrl+f/b), as tremc's overview.
Flickable {
    id: root

    property var torrent: null
    // Set once the details have loaded; the list's copy has none of these
    readonly property bool loaded: torrent?.files !== undefined

    readonly property real step: 46
    property bool pendingG: false

    function reset() {
        contentY = 0;
    }

    function scrollBy(by) {
        contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), contentY + by));
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const g = event.key === Qt.Key_G && !ctrl && event.text === "g";
        if (!g)
            pendingG = false;
        const half = Math.floor(height / 2);
        switch (event.key) {
        case Qt.Key_Space:
            more = !more;
            return true;
        case Qt.Key_J:
        case Qt.Key_K:
            if (ctrl)
                return false;
            scrollBy(event.key === Qt.Key_J ? step : -step);
            return true;
        case Qt.Key_N:
        case Qt.Key_P:
            if (!ctrl)
                return false;
            scrollBy(event.key === Qt.Key_N ? step : -step);
            return true;
        case Qt.Key_Down:
            scrollBy(step);
            return true;
        case Qt.Key_Up:
            scrollBy(-step);
            return true;
        case Qt.Key_D:
        case Qt.Key_U:
            if (!ctrl)
                return false;
            scrollBy(event.key === Qt.Key_D ? half : -half);
            return true;
        case Qt.Key_F:
        case Qt.Key_B:
            if (!ctrl)
                return false;
            scrollBy(event.key === Qt.Key_F ? height : -height);
            return true;
        case Qt.Key_PageDown:
            scrollBy(height);
            return true;
        case Qt.Key_PageUp:
            scrollBy(-height);
            return true;
        case Qt.Key_End:
            scrollBy(contentHeight);
            return true;
        case Qt.Key_Home:
            scrollBy(-contentHeight);
            return true;
        case Qt.Key_G:
            if (ctrl)
                return false;
            if (event.text === "G") {
                scrollBy(contentHeight);
            } else if (pendingG) {
                pendingG = false;
                scrollBy(-contentHeight);
            } else {
                pendingG = true;
                gTimer.restart();
            }
            return true;
        }
        return false;
    }

    // The rest of the rows shown, for good once opened (Space)
    property bool more: false

    // [label, value, key] rows: the summary first, the rest under "More
    // details". Rows without a value are left out.
    readonly property var summary: {
        const t = torrent;
        if (!t || !loaded)
            return [];
        const seeders = Format.seeders(t), leechers = Format.leechers(t);
        const speeds = [];
        if (t.rateDownload > 0)
            speeds.push(`↓ ${Format.speed(t.rateDownload)}`);
        if (t.rateUpload > 0)
            speeds.push(`↑ ${Format.speed(t.rateUpload)}`);
        const size = t.sizeWhenDone < t.totalSize ? `${Format.size(t.sizeWhenDone)} wanted of ${Format.size(t.totalSize)}` : Format.size(t.totalSize);
        const limit = Format.ratioLimitText(t);
        const swarm = [`${t.peersConnected} connected`];
        if (seeders >= 0)
            swarm.push(`${seeders} seeders`);
        if (leechers >= 0)
            swarm.push(`${leechers} leechers`);
        return [["Error", Format.hasError(t) ? t.errorString : ""], ["Size", `${size} · ${Format.percent(t.percentDone)} done`], ["Transferred", `${Format.size(t.downloadedEver)} down · ${Format.size(t.uploadedEver)} up`], ["Ratio", `${Format.ratio(t.uploadRatio)} · ${limit.startsWith("no") ? limit : `limit ${limit}`}`, "L"], ["Speed", speeds.length ? speeds.join(" · ") : "Idle"], ["Time left", t.status === Format.downloading ? Format.eta(t.eta) : ""], ["Swarm", swarm.join(" · ")], ["Location", t.downloadDir]].filter(r => r[1]);
    }

    readonly property var rest: {
        const t = torrent;
        if (!t || !loaded)
            return [];
        return [["Verified", Format.size(t.haveValid) + (t.corruptEver > 0 ? ` · ${Format.size(t.corruptEver)} corrupt` : "")], ["Peers", `${t.peersSendingToUs} sending to us · ${t.peersGettingFromUs} receiving`], ["Files", `${t.files.length}`], ["Pieces", `${t.pieceCount} × ${Format.size(t.pieceSize)}`], ["Added", Format.date(t.addedDate)], ["Completed", t.doneDate > 0 ? Format.date(t.doneDate) : ""], ["Downloading for", t.secondsDownloading > 0 ? Format.duration(t.secondsDownloading) : ""], ["Seeding for", t.secondsSeeding > 0 ? Format.duration(t.secondsSeeding) : ""], ["Created", t.dateCreated > 0 ? Format.date(t.dateCreated) : ""], ["Created by", t.creator], ["Comment", t.comment], ["Private", t.isPrivate ? "Yes, no DHT or PEX" : ""], ["Hash", t.hashString]].filter(r => r[1]);
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Behavior on contentY {
        enabled: !root.moving
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    Timer {
        id: gTimer

        interval: 600
        onTriggered: root.pendingG = false
    }

    Column {
        id: content

        width: root.width
        spacing: 14

        InfoGroup {
            rows: root.summary
        }

        // Opens and closes the rest, a row of its own
        Rectangle {
            visible: root.loaded
            width: content.width
            height: 46
            radius: Theme.radius
            color: toggleMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

            Icon {
                id: chevron

                x: 16
                name: "chevron"
                size: 20
                // The arrow points left; down to open, up to close
                rotation: root.more ? 90 : 270
                color: Theme.primary

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.emphasizedDecel
                    }
                }
            }

            Label {
                anchors.left: chevron.right
                anchors.leftMargin: 10
                text: root.more ? "Fewer details" : "More details"
                color: Theme.primary
            }

            Keycap {
                anchors.right: parent.right
                anchors.rightMargin: 14
                text: "Space"
            }

            MouseArea {
                id: toggleMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.more = !root.more
            }
        }

        InfoGroup {
            visible: root.more
            rows: root.rest
        }
    }

    // A key, as the launcher's keycaps
    component Keycap: Rectangle {
        property alias text: capLabel.text

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(26, capLabel.implicitWidth + 14)
        height: 26
        radius: 6
        color: Theme.surface_container_highest

        Label {
            id: capLabel

            anchors.centerIn: parent
            color: Theme.on_surface_variant
            font.pixelSize: 12
        }
    }

    // Rows of the launcher's grouped list: what each thing is on the left,
    // its value on the right, and the key that changes it
    component InfoGroup: Column {
        id: group

        property var rows: []

        width: parent?.width ?? 0
        spacing: 2

        Repeater {
            model: group.rows

            Rectangle {
                id: info

                required property var modelData
                required property int index
                readonly property real topCorners: index === 0 ? Theme.radius : 3
                readonly property real bottomCorners: index === group.rows.length - 1 ? Theme.radius : 3

                width: group.width
                height: 46
                topLeftRadius: topCorners
                topRightRadius: topCorners
                bottomLeftRadius: bottomCorners
                bottomRightRadius: bottomCorners
                color: Theme.surface_container_high

                Label {
                    id: name

                    x: 18
                    text: info.modelData[0]
                    color: Theme.on_surface
                }

                Label {
                    anchors.left: name.right
                    anchors.leftMargin: 24
                    anchors.right: keycap.visible ? keycap.left : parent.right
                    anchors.rightMargin: keycap.visible ? 10 : 18
                    horizontalAlignment: Text.AlignRight
                    text: info.modelData[1]
                    color: info.modelData[0] === "Error" ? Theme.error : Theme.on_surface_variant
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    font.family: info.modelData[0] === "Hash" ? Theme.monoFamily : Theme.fontFamily
                    elide: Text.ElideMiddle
                }

                Keycap {
                    id: keycap

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    visible: info.modelData[2] !== undefined
                    text: info.modelData[2] ?? ""
                }
            }
        }
    }
}
