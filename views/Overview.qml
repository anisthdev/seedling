import QtQuick
import ".."
import "../components"

// Everything about a torrent, in groups of the launcher's grouped-list
// rows: what each thing is on the left, its value on the right. The keys
// scroll it (j/k, gg/G, Ctrl+d/u, Ctrl+f/b), as tremc's overview.
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

    // [title, [[label, value, key], …]] for each group; rows without a
    // value are left out
    readonly property var groups: {
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
        const groups = [["Transfer", [["Error", Format.hasError(t) ? t.errorString : ""], ["Size", size], ["Done", `${Format.percent(t.percentDone)} · ${Format.size(t.haveValid)} verified`], ["Downloaded", Format.size(t.downloadedEver) + (t.corruptEver > 0 ? ` · ${Format.size(t.corruptEver)} corrupt` : "")], ["Uploaded", Format.size(t.uploadedEver)], ["Ratio", Format.ratio(t.uploadRatio)], ["Seed ratio limit", Format.ratioLimitText(t), "L"], ["Speed", speeds.length ? speeds.join(" · ") : "Idle"], ["Time left", t.status === Format.downloading ? Format.eta(t.eta) : ""]]], ["Swarm", [["Peers", `${t.peersConnected} connected · ${t.peersSendingToUs} sending to us · ${t.peersGettingFromUs} receiving`], ["Seeders", seeders >= 0 ? `${seeders}` : ""], ["Leechers", leechers >= 0 ? `${leechers}` : ""]]], ["Torrent", [["Location", t.downloadDir], ["Files", `${t.files.length}`], ["Pieces", `${t.pieceCount} × ${Format.size(t.pieceSize)}`], ["Added", Format.date(t.addedDate)], ["Completed", t.doneDate > 0 ? Format.date(t.doneDate) : ""], ["Downloading for", t.secondsDownloading > 0 ? Format.duration(t.secondsDownloading) : ""], ["Seeding for", t.secondsSeeding > 0 ? Format.duration(t.secondsSeeding) : ""], ["Created", t.dateCreated > 0 ? Format.date(t.dateCreated) : ""], ["Created by", t.creator], ["Comment", t.comment], ["Private", t.isPrivate ? "Yes, no DHT or PEX" : ""], ["Hash", t.hashString]]]];
        return groups.map(([title, rows]) => [title, rows.filter(r => r[1])]);
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

        Repeater {
            model: root.groups

            Column {
                id: group

                required property var modelData

                width: content.width
                spacing: 2

                // The group's name, as a list subheader
                Label {
                    anchors.verticalCenter: undefined
                    leftPadding: 4
                    bottomPadding: 6
                    text: group.modelData[0]
                    color: Theme.primary
                    font.pixelSize: 13
                }

                Repeater {
                    model: group.modelData[1]

                    Rectangle {
                        id: info

                        required property var modelData
                        required property int index
                        readonly property real topCorners: index === 0 ? Theme.radius : 3
                        readonly property real bottomCorners: index === group.modelData[1].length - 1 ? Theme.radius : 3

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

                        // The key that changes it, as the launcher's keycaps
                        Rectangle {
                            id: keycap

                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: info.modelData[2] !== undefined
                            width: 26
                            height: 26
                            radius: 6
                            color: Theme.surface_container_highest

                            Label {
                                anchors.centerIn: parent
                                text: info.modelData[2] ?? ""
                                color: Theme.on_surface_variant
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
