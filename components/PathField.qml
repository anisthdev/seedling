import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// A text field in the launcher's style, for a path (or anything else):
// Tab completes the path from the disk, as tremc's prompts do, showing the
// candidates under it when there are several; Up and Down go through
// `choices`. ~ stands for the home folder (see expanded). Enter and Esc
// are the owner's (submitted, cancelled).
Column {
    id: root

    property alias text: input.text
    property string placeholder
    // What Tab completes: "files", "dirs", or "" for nothing
    property string completion: "files"
    // Only these files (and folders) are offered, e.g. /\.torrent$/i
    property var fileFilter: null
    // Up and Down go through these
    property var choices: []
    readonly property bool focused: input.activeFocus
    readonly property string expanded: expand(input.text.trim())
    property var candidates: []
    property int choice: -1

    signal submitted
    signal cancelled

    function expand(path) {
        return path.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    function shorten(path) {
        const home = Quickshell.env("HOME");
        return path === home || path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function takeFocus(selectAll) {
        input.forceActiveFocus();
        if (selectAll)
            input.selectAll();
        else
            input.cursorPosition = input.text.length;
    }

    function complete() {
        if (completion === "" || lister.running)
            return;
        lister.prefix = expand(input.text);
        lister.running = true;
    }

    function use(found) {
        const matches = found.filter(p => p.endsWith("/") || (completion === "files" && (!fileFilter || fileFilter.test(p))));
        if (matches.length === 0) {
            candidates = [];
            return;
        }
        // As far as all of them agree
        let common = matches[0];
        for (const m of matches)
            while (!m.startsWith(common))
                common = common.slice(0, -1);
        input.text = shorten(common);
        input.cursorPosition = input.text.length;
        candidates = matches.length > 1 ? matches.map(m => m.replace(/\/$/, "").split("/").pop() + (m.endsWith("/") ? "/" : "")) : [];
    }

    width: parent?.width ?? 0
    spacing: 6

    onTextChanged: if (!lister.running)
        candidates = []

    Rectangle {
        width: parent.width
        height: 46
        radius: Theme.radius
        color: Qt.alpha(Theme.surface_container_highest, 1)
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.takeFocus(false)
        }

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.on_surface
            selectionColor: Theme.primary
            selectedTextColor: Theme.on_primary
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
            clip: true

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Tab:
                    root.complete();
                    break;
                case Qt.Key_Up:
                case Qt.Key_Down:
                    if (root.choices.length === 0)
                        return;
                    root.choice = (root.choice + (event.key === Qt.Key_Down ? 1 : -1) + root.choices.length) % root.choices.length;
                    input.text = root.shorten(root.choices[root.choice]);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.submitted();
                    break;
                case Qt.Key_Escape:
                    root.cancelled();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 16
            visible: input.text === ""
            text: root.placeholder
            color: Theme.on_surface_variant
            font.pixelSize: 15
            font.weight: Font.Normal
        }
    }

    // What Tab found, when it's more than one
    Label {
        anchors.verticalCenter: undefined
        visible: root.candidates.length > 0
        width: parent.width
        leftPadding: 4
        text: root.candidates.slice(0, 12).join("   ") + (root.candidates.length > 12 ? `   and ${root.candidates.length - 12} more` : "")
        color: Theme.on_surface_variant
        font.pixelSize: 12
        font.weight: Font.Normal
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }

    // Lists what starts with the prefix, folders with a / after them
    Process {
        id: lister

        property string prefix

        command: ["sh", "-c", "for f in \"$1\"*; do if [ -d \"$f\" ]; then printf '%s/\\n' \"$f\"; elif [ -e \"$f\" ]; then printf '%s\\n' \"$f\"; fi; done", "sh", prefix]
        stdout: StdioCollector {
            onStreamFinished: root.use(text.split("\n").filter(l => l !== ""))
        }
    }
}
